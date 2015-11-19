require 'set'

class Event < ActiveRecord::Base
  def self.availabilities(date_from, duration=30.minutes)
    pitch = 5.minutes

    unless duration % pitch == 0
      raise ArgumentError.new('duration must be a multiple of %d minutes' % (pitch.to_i / 60))
    end

    date_from = date_from.to_date

    # Retrieve all events affecting `date_from` and the 6 following days.
    events = Event.where('starts_at < ?', date_from + 7.days)
                  .where('starts_at >= ? OR weekly_recurring = ?', date_from, true)
                  .order(starts_at: :asc)

    # Normalize events.
    events = events.map do |event|
      date = event.starts_at.to_date

      # Calculate the number of weeks between the event date and `date_from` (will
      # be 0 for non-recurring events).
      offset = ((date_from - 1 - date).to_i / 7 + 1).weeks

      date += offset
      starts_at, ends_at = [event.starts_at, event.ends_at].map { |d| d.beginning_of_minute + offset }

      { date: date, kind: event.kind, starts_at: starts_at, ends_at: ends_at }
    end

    # Extract available slots from events (grouped them by day).
    availabilities = {}
    events.group_by { |e| e[:date] }.map do |date, events|
      # Discretize events and group them by kind.
      slots = { 'opening' => SortedSet.new, 'appointment' => Set.new }
      events.each do |event|
        slot = event[:starts_at]
        while slot < event[:ends_at] do
          slots[event[:kind]] << slot
          slot += pitch
        end
      end

      # Resolve availabilities.
      slots = (slots['opening'] - slots['appointment']).to_a

      if (duration > pitch)
        n = duration / pitch # Number of slots needed to cover `duration`.

        # "Merge" slots:
        #   1. Split slots in chunks of contiguous slots.
        #   2. Truncate chunks so that their sizes are a multiple of `n`.
        #   3. Pick a slot every `n` slots from each chunk.
        slots = slots.slice_when { |slot, next_slot| next_slot - slot > pitch }          # (1)
                     .map { |slots| slots.first(slots.size - slots.size % n) }           # (2)
                     .flat_map { |slots| slots.select.with_index { |_, i| i % n == 0 } } # (3)
      end

      availabilities[date] = slots
    end

    # Return available slots for `date_from` and the 6 following days.
    date_from.upto(date_from + 6.days).map do |date|
      slots = availabilities[date] || []
      { date: date, slots: slots.map { |s| s.strftime('%-H:%M') } }
    end
  end
end
