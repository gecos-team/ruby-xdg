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
require './constants'
require './core'


module Bang
    class ClockLabel < Qt::Label
        include FontHandle, BangWidget
        attr_accessor :timer, :date_format, :time_zone
        def initialize(date_format = '%a, %d %b %Y %H:%M:%S', time_zone = GUI::CONST['TIMEZONE'])
            super(Time.now.strftime date_format)
            @date_format = date_format
            @time_zone = time_zone
            @timer = Qt::Timer.new(self)
            @timer.connect(SIGNAL :timeout) do
                self.set_text(Time.tz(@time_zone).strftime(@date_format))
                self.update
            end
        end

        def start
            @timer.start(1000)
        end
    end

    class Calendar < WidgetMenu
        attr_accessor :timer, :date_format
        def initialize(date_format = '%Z: %a, %d %b %Y %H:%M')
            super(Time.now.strftime date_format)
            @date_format = date_format
            self.add_clock("%B %e, %Y")
            self.add_widget(Qt::CalendarWidget.new)
            self.add_separator
            self.add_clock('  ' + date_format, GUI::CONST['TIMEZONE'], Qt::AlignLeft)
            self.add_clock('  ' + date_format, 'UTC', Qt::AlignLeft)
            @timer = Qt::Timer.new(self)
            @timer.connect(SIGNAL :timeout) do
                self.set_title(Time.now.strftime @date_format)
                self.update
            end
        end

        def add_clock(date_format, time_zone = GUI::CONST['TIMEZONE'], align = Qt::AlignHCenter)
            clock = ClockLabel.new(date_format, time_zone)
            clock.set_alignment(align)
            clock.set_font_size(10)
            self.add_widget(clock)
            clock.start
        end

        def start
            @timer.start(1000)
        end
    end
end

if __FILE__ == $PROGRAM_NAME
    app = Bang::Session.new
    window = Bang::TestWindow.new
    calendar = Bang::Calendar.new
    window.add_menu(calendar)
    calendar.start
    window.show
    app.exec()
end
