#!/usr/bin/env ruby

# Copyright (c) 2012, Christopher L. Ramsey <christopherlramsey@gmx.us>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met: Redistributions of
# source code must retain the above copyright notice, this list of conditions and
# the following disclaimer. Redistributions in binary form must reproduce the
# above copyright notice, this list of conditions and the following disclaimer in
# the documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
# ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
require '../gui/core'
require '../gui/constants'
require '../io/dbus'



module Bang
    class PowerMonitor < DBusClient
        @@state = [:UNKNOWN, :CHARGING, :DISCHARGING, :EMPTY, :FULLY_CHARGED, :PENDING_CHARGE, :PENDING_DISCHARGE]
        self.service = "org.freedesktop.UPower"
        self.bus = "ruby.dbus.SystemBus"
        attr_reader :battery, :stats, :acad
        def initialize
            super()
            @battery = self.reflect('battery_BAT1')
            @stats = self.reflect('UPower')
            @acad = self.reflect('line_power_ACAD')
        end
        def status
            State.new(@stats[:OnBattery], @stats[:OnLowBattery])
        end
        def state
            @@state[@battery.get(:State)]
        end
        def time_till(state)
            case state
            when :empty
                Status.new(TimeSpan.new(@battery[:TimeToEmpty]), @battery[:Percentage])
            when :full
                Status.new(TimeSpan.new(@battery[:TimeToFull]), @battery[:Percentage])
            end
        end
        Status = Struct.new(:until, :percentage)
        State = Struct.new(:on_battery, :battery_low)
    end

    module Monitored
        @@dbus = PowerMonitor.new
    end

    class BatteryLabel < Qt::Label
        include Monitored
        def_delegator :@timer , :start, :start
        def initialize
            super('Power')
            @timer = Qt::Timer.new(self)
            @timer.set_interval(1000)
            @timer.connect(SIGNAL :timeout) do
                case @@dbus.state
                when :CHARGING
                    time = @@dbus.time_till(:full)
                    span = time.until
                    self.set_text("Pluged In, Charging (#{span.hrs_s} hrs #{span.secs_s} mins left, at #{time.percentage.round}%)")
                when :DISCHARGING
                    time = @@dbus.time_till(:empty)
                    span = time.until
                    self.set_text("On Battery (#{span.hrs_s} hrs #{span.secs_s} mins left, at #{time.percentage.round}%)")
                when :FULLY_CHARGED
                    self.set_text("Pluged In, Fully Charged (100%)")
                when :EMPTY
                    self.set_text("Dead Battery (0%)")
                when :PENDING_CHARGE
                    self.set_text("Charge Pending")
                when :PENDING_DISCHARGE
                    self.set_text("Discharge Pending")
                when :UNKNOWN
                    self.set_text("Something is Wrong!")
                end
            end
        end
    end

    class BatteryAnimation < Qt::Action
        include Monitored
        def_delegator :@timer, :start, :start
        CHARGING = {(0..10) => "battery-caution-charging-symbolic", (11..24) => "battery-empty-charging-symbolic", (25..49) => "battery-low-charging-symbolic", (50..79) => "battery-good-charging-symbolic", (80..98) => "battery-full-charging-symbolic", (99..100) => "battery-full-charged-symbolic"}
        DISCHARGING = {(0..10) => "battery-caution-symbolic", (11..24) => "battery-empty-symbolic", (25..49) => "battery-low-symbolic", (50..79) => "battery-good-symbolic", (80..100) => "battery-full-symbolic"}
        def initialize
            @timer = Qt::Timer.new(self)
            @timer.set_interval(1000)
            @timer.connect(SIGNAL :timeout) do
                #impl here
            end
        end

        def self.icon(on_battery, percentage)
            icons = on_battery ? DISCHARGING : CHARGING
            icons.each do |r, n|
                if r.cover?(percentage)
                    return n
                end
            end
        end
    end

    class PowerClock < WidgetMenu
        include Monitored
        def_delegator :@timer, :start, :start
        def initialize
            super('Power')
            @status, @clock = self.add_actions(Qt::Action.new(self), Qt::Action.new(self))
            @percentage = self.add_widget(ProgressMeter.new)
            @timer = Qt::Timer.new(self)
            @timer.set_interval(1000)
            @timer.connect(SIGNAL :timeout) do
                case @@dbus.state
                when :CHARGING
                    time = @@dbus.time_till(:full)
                    span = time.until
                    s = 'Pluged In, Charging'
                    c = "#{span.hrs_s} hrs #{span.secs_s} mins left"
                    v = time.percentage.round
                when :DISCHARGING
                    time = @@dbus.time_till(:empty)
                    span = time.until
                    s = 'On Battery'
                    c = "#{span.hrs_s} hrs #{span.secs_s} mins left"
                    v = time.percentage.round
                when :FULLY_CHARGED
                    time = @@dbus.time_till(:empty)
                    s = 'Pluged In, Fully Charged'
                    c = 'N/A'
                    v = 100
                when :EMPTY
                    s = 'Dead Battery'
                    c = "(NONE)"
                    v = 0
                when :PENDING_CHARGE
                    time = @@dbus.time_till(:empty)
                    span = time.until
                    s = 'Charge Pending'
                    c = "#{span.hrs_s} hrs #{span.secs_s} mins left"
                    v = time.percentage.round
                when :PENDING_DISCHARGE
                    time = @@dbus.time_till(:full)
                    span = time.until                    
                    s = 'Discharge Pending'
                    c = "#{span.hrs_s} hrs #{span.secs_s} mins left"
                    v = time.percentage.round
                when :UNKNOWN
                    s = 'Something is Wrong!'
                    c = "(NONE)"
                    v = 0
                end
                @status.set_text(s)
                @clock.set_text(c)
                @percentage.set_value(v)
                self.set_title("(#{v}%)")
                self.set_icon(ICON v)
            end
        end

        private
        def ICON(percentage)
            name = BatteryAnimation.icon(@@dbus.status.on_battery, percentage)
            item = GUI::CONST['ICON THEME'].find_icon_in_folder('status', name, 'scalable')[-1]
            Qt::Icon.new(item)
        end
    end
end

if __FILE__ == $PROGRAM_NAME
    app = Bang::Session.new
    window = Bang::TestWindow.new
    power = Bang::PowerClock.new
    window.add_menu(power)
    power.start
    window.show
    app.exec()
end