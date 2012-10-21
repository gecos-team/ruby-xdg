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

class ClockLabel < Qt::Label
    attr_accessor :timer, :date_format
    slots :start
    def initialize(date_format = '%Y-%d-%mT%H:%M:%S')
        super(Time.now.strftime date_format)
        @date_format = date_format
    end

    def start
        @timer = Qt::Timer.new(self)
        @timer.connect(SIGNAL :timeout) do
            self.set_text(Time.now.strftime @date_format)
            self.update
        end        
        @timer.start(1000)
    end
end

class Calendar < Qt::Menu
    attr_accessor :timer, :date_format    
    signals :start
    def initalize(date_format = '%Y-%d-%mT%H:%M:%S')
        super(Time.now.strftime date_format)
        self.add_widget(Qt::Calendar.new)
        self.add_widget(ClockLabel.new.start)
        self.add_widget(ClockLabel.new.start)
    end

    def add_widget(widget)
        self.add_action(Qt::WidgetAction.new widget)
    end

    def start
        @timer = Qt::Timer.new(self)
        @timer.connect(SIGNAL :timeout) do
            self.set_title(Time.now.strftime @date_format)
            self.update
        end        
        @timer.start(1000)
    end
end

if __FILE__ == $PROGRAM_NAME
    app = Qt::Application.new([])
    clock = ClockLabel.new()
    clock.start
    clock.show
    app.exec()
end
