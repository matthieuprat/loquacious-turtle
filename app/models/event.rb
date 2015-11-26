class Event < ActiveRecord::Base
  def self.availabilities(date, duration = 30.minutes)
    duration = duration.to_f / 1.day
    date = date.to_date

    events = self.fetch(date, date + 7.days)
    avails = self.compute_availabilities(events)

    # Chunk availability periods into slots and group them by day.
    slots = avails.map { |a| a.begin.to_datetime.step(a.end.to_datetime - duration, duration) }
                  .flat_map(&:to_a)
                  .group_by(&:to_date)

    date.upto(date + 6.days).map do |date|
      { date: date, slots: (slots[date] || []).map { |s| s.strftime('%-H:%M') } }
    end
  end

  private

  # Retrieve events affecting a date range.
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

  # Compute an array of date ranges representing availability periods.
  def self.compute_availabilities(events)
    return [] if events.empty?

    # Reshape events and sort them by start date.
    events = events.map { |e| [e.kind.to_sym, e.starts_at..e.ends_at] }
                   .sort_by { |_, r| r.begin }

    avails = [] # Array of date ranges representing availability periods.
    kind, avail = events.shift
    avail = avail.end..avail.end if kind == :appointment

    events.each do |kind, event|
      case kind
      when :opening
        if event.begin > avail.end
          avails << avail
          avail = event
        else
          avail = avail.begin..[avail.end, event.end].max
        end
      when :appointment
        next unless event.end > avail.begin
        avails << (avail.begin..[avail.end, event.begin].min)
        avail = event.end..[avail.end, event.end].max
      end
    end
    avails << avail
  end
end
