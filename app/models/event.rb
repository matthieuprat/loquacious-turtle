require 'set'

class Event < ActiveRecord::Base
  def self.availabilities(date_from)
    pitch = 30.minutes
    date_from = date_from.to_date

    # Retrieve all events affecting `date_from` and the 6 following days.
    events = Event.where('starts_at < ?', date_from + 7.days)
                  .where('starts_at >= ?', date_from)
                  .order(starts_at: :asc)

    # Discretize events and group them by kind.
    slots = { 'opening' => SortedSet.new, 'appointment' => Set.new }
    events.each do |event|
      slot = event.starts_at
      while slot < event.ends_at do
        slots[event.kind] << slot
        slot += pitch
      end
    end

    # Resolve available slots and group them by day.
    availabilities = (slots['opening'] - slots['appointment'])
                     .group_by { |slot| slot.to_date }

    # Return available slots for `date_from` and the 6 following days.
    date_from.upto(date_from + 6.days).map do |date|
      slots = availabilities[date] || []
      { date: date, slots: slots.map { |s| s.strftime('%-H:%M') } }
    end
  end
end
