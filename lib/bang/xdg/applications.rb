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

require_relative 'core'
require_relative 'constants'

$CONST['XDG APP DIRS'] = $CONST['XDG DATA DIRS'].map {|d| File.join d, '/applications'}.select {|d| Dir.exists? d}
$CONST['XDG DIR DIRS'] = $CONST['XDG DATA DIRS'].map {|d| File.join d, '/desktop-directories'}.select {|d| Dir.exists? d}


class DesktopEntry < IniFile
    attr_reader :data
    attr_reader :name, :generic_name, :encoding, :type, :icon, :comment
    attr_reader :mime_type, :categories, :url
    attr_reader :app_exec, :type_exec, :terminal
    attr_reader :no_display, :hidden, :only_show_in, :not_show_in
    attr_reader :startup_notify, :startup_wm_class
    def initalize(path)
        super()
        self.parse(path)
    end

    def parse(path)
        super(path)
        if self.info != nil
            @main = self.get_section('Desktop Entry')
            @name = @main['Name']
            @generic_name = @main['Generic Name']
            @encoding = @main['Encoding']
            @type = @main['Type']
            @icon = @main['Icon']
            @comment = @main['Comment']
            @mime_type = @main['MimeType']
            @categories = @main['Categories', :List]
            @url = @main['URL']
            @app_exec = @main['AppExec']
            @type_exec = @main['TypeExec']
            @terminal = @main['Terminal', :List]
            @no_display = @main['NoDisplay', :Bool]
            @hidden = @main['Hidden', :Bool]
            @only_show_in = @main['OnlyShowIn']
            @not_show_in = @main['NotShowIn']
            @startup_notify = @main['StartupNotify', :Bool]
            @startup_wm_class = @main['StartupWMClass']
        end
    end

    def eql?(entry)
        @name == entry.name && File.basename(self.info.path) == File.basename(entry.info.path)
    end

    def to_s
        return "\"#{@name}\" #{File.basename(self.info.path)}"
    end

    def self.by_name(name)
        self.new(AppCache::APPS[name])
    end
end

module AppCache
    #this is a global application cache
    APPS = Hash.new
    for dir in $CONST['XDG APP DIRS']
        Dir.foreach(dir) do |file|
            if file =~ /.+\.desktop$/
                APPS[file] = File.join(dir, file)
            end
        end
    end

    def AppCache.each(&pass)
        for name, file in APPS
            yield name, file
        end
    end

    def AppCache.each_app(&pass)
        for name, file in APPS
            yield DesktopEntry.new(file)
        end
    end
end

if __FILE__ == $PROGRAM_NAME
    ini = IniFile.new('/usr/share/applications/ubuntu-software-center.desktop')
    ini.each do |section|
        puts section.head
        puts section
    end
end