require 'set'

class Event < ActiveRecord::Base
  @@precision = 5.minutes

  def self.availabilities(date, duration = 30.minutes)
    date = date.to_date

    events = self.fetch(date, date + 7.days)
    slots = self.discretize(events, duration)

    slots = slots.group_by { |s| s.to_date }

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

  # Extract available slots from events.
  def self.discretize(events, duration)
    precision = [duration, @@precision].min

    slots = { 'opening' => SortedSet.new, 'appointment' => Set.new }
    events.each do |e|
      from, to = [e.starts_at, e.ends_at].map do |d|
        Time.at((d.to_f / precision).round * precision).to_datetime.utc
      end

      slots[e.kind].merge(from.step(to - precision, precision.to_f / 1.day))
    end

    # Resolve availabilities.
    slots = (slots['opening'] - slots['appointment']).to_a

    if (duration > precision)
      # "Merge" slots:
      #   1. Split slots in chunks of contiguous slots.
      #   2. Truncate chunks so that their sizes are a multiple of `n`.
      #   3. Pick a slot every `n` slots from each chunk.
      n = duration / precision # Number of slots needed to cover `duration`.
      slots.slice_when { |slot, next_slot| (next_slot - slot).days > precision } # (1)
           .map { |slots| slots.first(slots.size - slots.size % n) }             # (2)
           .flat_map { |slots| slots.select.with_index { |_, i| i % n == 0 } }   # (3)
    else
      slots
    end
  end
end
