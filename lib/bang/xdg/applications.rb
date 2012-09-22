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

require '.\bang\xdg\core'
require '.\bang\xdg\constants'

$CONST['XDG APP DIRS'] = $CONST['XDG DATA DIRS'].map {|d| File.join d, '/applications'}.select {|d| File.exists? d}

class DesktopEntry < IniFile
    attr_reader :data
    attr_reader :name, :generic_name, :encoding, :type, :icon, :comment
    attr_reader :mime_type, :categories, :url
    attr_reader :app_exec, :type_exec, :terminal
    attr_reader :no_display, :hidden, :only_show_in, :not_show_in
    attr_reader :startup_notify, :startup_wm_class
    def initalize path = nil
        super()
        self.parse path
    end

    def parse path
        super path
        if self.info != nil
            @data = self.get_section('Desktop Entry')
            @name = @data['Name']
            @generic_name = @data['Generic Name']
            @encoding = @data['Encoding']
            @type = @data['Type']
            @icon = @data['Icon']
            @comment = @data['Comment']
            @mime_type = @data['MimeType']
            @categories = @data['Categories', :List]
            @url = @data['URL']
            @app_exec = @data['AppExec']
            @type_exec = @data['TypeExec']
            @terminal = @data['Terminal', :List]
            @no_display = @data['NoDisplay', :Bool]
            @hidden = @data['Hidden', :Bool]
            @only_show_in = @data['OnlyShowIn', :Bool]
            @not_show_in = @data['NotShowIn', :Bool]
            @startup_notify = @data['StartupNotify', :Bool]
            @startup_wm_class = @data['StartupWMClass']
        end
    end
end

$APPS = Hash.new
for dir in $CONST['XDG APP DIRS']
    Dir.foreach(dir) do |file|
        if file =~ /.+\.desktop$/
            $APPS[file] = DesktopEntry.new File.join(dir, file)
        end
    end
end