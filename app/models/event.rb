require 'set'

class Event < ActiveRecord::Base
  def self.availabilities(date, duration = 30.minutes)
    duration = duration.seconds
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

    # Compute availability periods.
    avails = [] # Array of date ranges.
    avail = DateTime.new(0)..DateTime.new(0) # "Fake" availability for initialization.
    events.sort_by { |_, e| e.begin }.each do |kind, event|
      case kind
      when :opening
        if event.begin > avail.end
          avails << avail
          avail = event
        else
          avail = avail.begin..[avail.end, event.end].max
        end
      when :appointment
        avails << (avail.begin..event.begin)
        avail = event.end..avail.end
      end
    end
    avails << avail
    avails.shift # Slash the fake availability.

    # Chunk availability periods into slots and group them by day.
    slots = avails.map { |a| a.begin.step(a.end - duration, duration.fdiv(1.day)) }
                  .flat_map(&:to_a)
                  .group_by(&:to_date)

    date.upto(date + 6.days).map do |date|
      { date: date, slots: (slots[date] || []).map { |s| s.strftime('%-H:%M') } }
    end
  end
end
