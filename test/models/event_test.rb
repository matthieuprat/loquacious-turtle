require 'test_helper'

class EventTest < ActiveSupport::TestCase
  test "no event" do
    date = DateTime.parse('2014-08-10')
    availabilities = Event.availabilities date
    date.upto(date + 6.days).each_with_index do |date, i|
      assert_equal date, availabilities[i][:date]
      assert_equal [], availabilities[i][:slots]
    end
    assert_equal 7, availabilities.length
  end

  test "opening" do
    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-11 09:30'), ends_at: DateTime.parse('2014-08-11 11:30')
    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-12 09:15'), ends_at: DateTime.parse('2014-08-12 11:00')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['9:30', '10:00', '10:30', '11:00'], availabilities[1][:slots]
    assert_equal ['9:15', '9:45', '10:15'], availabilities[2][:slots]
  end

  test "opening and appointment" do
    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-11 09:30'), ends_at: DateTime.parse('2014-08-11 12:30')
    Event.create kind: 'appointment', starts_at: DateTime.parse('2014-08-11 10:30'), ends_at: DateTime.parse('2014-08-11 11:30')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['9:30', '10:00', '11:30', '12:00'], availabilities[1][:slots]

    Event.create kind: 'appointment', starts_at: DateTime.parse('2014-08-11 09:30'), ends_at: DateTime.parse('2014-08-11 10:30')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['11:30', '12:00'], availabilities[1][:slots]

    Event.create kind: 'appointment', starts_at: DateTime.parse('2014-08-11 12:00'), ends_at: DateTime.parse('2014-08-11 12:30')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['11:30'], availabilities[1][:slots]
  end

  test "recurring opening and appointment" do
    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-04 09:30'), ends_at: DateTime.parse('2014-08-04 12:30'), weekly_recurring: true
    Event.create kind: 'appointment', starts_at: DateTime.parse('2014-08-11 10:30'), ends_at: DateTime.parse('2014-08-11 11:30')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['9:30', '10:00', '11:30', '12:00'], availabilities[1][:slots]
  end

  test "overlap between openings" do
    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-11 09:30'), ends_at: DateTime.parse('2014-08-11 12:00')
    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-04 10:00'), ends_at: DateTime.parse('2014-08-04 12:00'), weekly_recurring: true
    Event.create kind: 'appointment', starts_at: DateTime.parse('2014-08-11 10:30'), ends_at: DateTime.parse('2014-08-11 11:30')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['9:30', '10:00', '11:30'], availabilities[1][:slots]

    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-11 10:00'), ends_at: DateTime.parse('2014-08-11 11:00')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['9:30', '10:00', '11:30'], availabilities[1][:slots]
  end

  test "appointment not scheduled on opening" do
    Event.create kind: 'appointment', starts_at: DateTime.parse('2014-08-11 09:30'), ends_at: DateTime.parse('2014-08-11 10:30')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal [], availabilities[1][:slots]

    Event.create kind: 'appointment', starts_at: DateTime.parse('2014-08-11 11:30'), ends_at: DateTime.parse('2014-08-11 12:30')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal [], availabilities[1][:slots]

    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-11 10:30'), ends_at: DateTime.parse('2014-08-11 11:00')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['10:30'], availabilities[1][:slots]
  end

  test "overlap between opening and appointment" do
    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-11 09:30'), ends_at: DateTime.parse('2014-08-11 10:30')
    Event.create kind: 'appointment', starts_at: DateTime.parse('2014-08-11 10:00'), ends_at: DateTime.parse('2014-08-11 11:00')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['9:30'], availabilities[1][:slots]

    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-11 10:30'), ends_at: DateTime.parse('2014-08-11 11:30')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['9:30', '11:00'], availabilities[1][:slots]
  end

  test "overlap between appointments" do
    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-11 09:00'), ends_at: DateTime.parse('2014-08-11 11:00')
    Event.create kind: 'appointment', starts_at: DateTime.parse('2014-08-11 10:00'), ends_at: DateTime.parse('2014-08-11 12:00')
    Event.create kind: 'appointment', starts_at: DateTime.parse('2014-08-11 10:00'), ends_at: DateTime.parse('2014-08-11 11:00')
    Event.create kind: 'opening', starts_at: DateTime.parse('2014-08-11 11:00'), ends_at: DateTime.parse('2014-08-11 12:00')

    availabilities = Event.availabilities DateTime.parse('2014-08-10')
    assert_equal ['9:00', '9:30'], availabilities[1][:slots]
  end
end
