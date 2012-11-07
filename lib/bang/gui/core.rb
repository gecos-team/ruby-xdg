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
require "Qt4"
require "active_support/core_ext/time/zones"
require "dbus"
require "../xdg/core"

module Bang
    class Session < Qt::Application
        def initialize(args = ['-stylesheet'])
            args << '-stylesheet' if !args.include?('-stylesheet')
            super(args)
        end

        def css=(style)
            self.set_style_sheet(style)
        end

        def css
            self.style_sheet
        end
    end

    class TestWindow < Qt::MainWindow
        def_delegator :@menu_bar, :add_menu, :add_menu
        def initialize
            super()
            @menu_bar = Qt::MenuBar.new
            self.set_menu_bar(@menu_bar)
        end
    end

    module BangWidget
        def css=(style)
            self.set_style_sheet(style)
        end

        def css
            self.style_sheet
        end
    end

    class WidgetMenu < Qt::Menu 
        include BangWidget
        def add_widget(widget)
            action = Qt::WidgetAction.new(self)
            action.set_default_widget(widget)
            self.add_action(action)
        end
    end

    module FontHandle
        def set_font_size(pt)
            font = self.font
            font.set_point_size_f(pt)
            self.set_font(font)
        end
    end

end

class Time
    def self.tz(time_zone)
        Time.zone = time_zone
        return Time.zone.now
    end
end

class TimeSpan
    attr_reader :hours, :minutes, :seconds
    def initialize(seconds)
        @hours = (seconds/3600).to_i
        @minutes = (seconds/60 - @hours*60).to_i
        @seconds = (seconds - (@minutes * 60 + @hours * 3600)).to_i
    end

    def hrs_s
        @hours < 10 ? '0' + @hours.to_s : @hours.to_s
    end

    def mins_s
        @minutes < 10 ? '0' + @minutes.to_s : @minutes.to_s
    end

    def secs_s
        @seconds < 10 ? '0' + @seconds.to_s : @seconds.to_s
    end

    def to_s
        if @hours == 0
            "#{@minutes < 10 ? '0' + @minutes.to_s : @minutes.to_s}:#{@seconds < 10 ? '0' + @seconds.to_s : @seconds.to_s}"
        elsif @hours == 0 && @minutes == 0
            "#{@seconds}"
        else
            "#{@hours < 10 ? '0' + @hours.to_s : @hours.to_s}:#{@minutes < 10 ? '0' + @minutes.to_s : @minutes.to_s}:#{@seconds < 10 ? '0' + @seconds.to_s : @seconds.to_s}"
        end
    end
end



if __FILE__ == $PROGRAM_NAME

end