class Event < ActiveRecord::Base
  def self.availabilities(date, duration = 30.minutes)
    duration = duration.fdiv(1.day)
    date = date.to_date

    # Retrieve all events affecting `date` and the 6 following days.
    events = Event.where('starts_at < ?', date + 7.days)
                  .where('starts_at >= ? OR weekly_recurring = ?', date, true)
                  .order(starts_at: :asc)
                  .to_a

    # Reshape events.
    events.map! do |e|
      starts_at = e.starts_at.to_datetime
      ends_at   = e.ends_at.to_datetime
      if e.weekly_recurring
        # Shift event dates.
        offset = ((date - 1 - starts_at.to_date).to_i / 7 + 1).weeks
        starts_at += offset
        ends_at   += offset
      end
      [e.kind.to_sym, starts_at..ends_at]
    end

    events.sort_by! { |_, e| e.begin }

    # Compute availability periods.
    avails = [] # Array of date ranges representing availability periods.
    avail = nil # Next (candidate) availability period.
    unless events.empty?
      kind, avail = events.shift
      avail = avail.end..avail.end if kind == :appointment
    end
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
    avails << avail if avail

    # Chunk availability periods into slots and group them by day.
    slots = avails.map { |a| a.begin.step(a.end - duration, duration) }
                  .flat_map(&:to_a)
                  .group_by(&:to_date)

    date.upto(date + 6.days).map do |date|
      { date: date, slots: (slots[date] || []).map { |s| s.strftime('%-H:%M') } }
    end
  end
end
