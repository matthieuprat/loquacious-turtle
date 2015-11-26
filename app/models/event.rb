require 'set'

class Event < ActiveRecord::Base
  def self.availabilities(date, duration = 30.minutes)
    date = date.to_date

    events = self.fetch(date, date + 7.days)
    slots = self.discretize(events, duration)

    # Return available slots for `date` and the 6 following days.
    date.upto(date + 6.days).map do |date|
      { date: date, slots: (slots[date] || []).map { |s| s.strftime('%-H:%M') } }
    end
  end

  private

  # Retrieve all events affecting the supplied date range.
  def self.fetch(from, to)
    events = Event.where('starts_at < ?', to)
                  .where('starts_at >= ? OR weekly_recurring = ?', from, true)
                  .order(starts_at: :asc)

    events.map do |event|
      if event.weekly_recurring
        # Shift event dates.
        offset = ((from - 1 - event.starts_at.to_date).to_i / 7 + 1).weeks
        event.starts_at += offset
        event.ends_at   += offset
      end
      event
    end
  end

  # Extract available slots from events, grouped by day.
  def self.discretize(events, duration)
    availabilities = {}
    events.group_by { |e| e.starts_at.to_date }.map do |date, events|
      # Find the highest suitable pitch to discretize events.
      first = events[0].starts_at
      pitch = events.reduce(duration / 1.minute) { |pitch, event|
        [event.starts_at, event.ends_at].map { |t| pitch.gcd((t - first).to_i / 60) }.min
      }.minutes

      # Discretize events and group them by kind.
      slots = { 'opening' => SortedSet.new, 'appointment' => Set.new }
      events.each do |event|
        slot = event.starts_at
        while slot < event.ends_at do
          slots[event.kind] << slot
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

    availabilities
  end
end
