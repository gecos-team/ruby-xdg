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
require './core'
require '../io/dbus'

module Bang
    class PowerMonitor < DBusClient
        @@state = [:UNKNOWN, :CHARGING, :DISCHARGING, :EMPTY, :FULLY_CHARGED, :PENDING_CHARGE, :PENDING_DISCHARGE]
        self.bus = DBusSettings::SYSTEM_BUS
        self.service = "org.freedesktop.UPower"
        attr_reader :battery, :stats, :acad
        def initialize
            super()
            @battery = self.reflect('battery_BAT1')
            @stats = self.reflect('UPower')
            @acad = self.reflect('line_power_ACAD')
        end
        def status
            State.new(@status[:OnBattery], @status[:OnLowBattery])
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
        State = Struct.new(:battery?, :battery_low?)
    end

    module Monitored
        @@dbus = PowerMonitor.new
    end

    class BatteryLabel < Qt::Label
        include Monitored
        def initialize
            super('Power')
            @timer = Qt::Timer.new(self)
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
                when :PENDING_CHARGE
                    self.set_text("Discharge Pending")
                when :UNKNOWN
                    self.set_text("Something is Wrong!")
                end
            end
        end
        def start
            @timer.start(1000)
        end
    end

    class PowerClock < WidgetMenu
        include Monitored
        def initialize(update = 5000)
            super(); @update = update
        end

        def start
            @timer.start(@update)
        end
    end
end

if __FILE__ == $PROGRAM_NAME
    app = Bang::Session.new
    #window = Bang::TestWindow.new
    power = Bang::BatteryLabel.new
    power.start
    power.show
    #window.add_menu(power)
    #calendar.start
    #window.show
    app.exec()

end