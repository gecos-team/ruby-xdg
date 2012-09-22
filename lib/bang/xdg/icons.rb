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


$CONST['XDG ICON DIRS'] = $CONST['XDG DATA DIRS'].map{|d| File.join(d, 'themes')}.select{|d| File.exists? d} + [File.join($HOME, '.themes')]

$STD = Hash.new
$STD['STD ICON SIZES'] = %w(16 24 32 36 48 64 72 96 128 160 192 256 scalable)
$STD['STD ICON EXTENSIONS'] = ['png', 'svg', 'xpm']

class IconDirectory < Section
    attr_reader :size, :context, :type
    attr_reader :min_size, :max_size

    def initalize section
        super section.head, section.fields
        @size = section['Size']
        @context = section['Context']
        @type = section['Type']
        @min_size = section['MinSize']
        @max_size = section['MaxSize']
    end
end

class IconTheme < IniFile
    attr_reader :main, :directories
    attr_reader :name, :comment, :inherits, :example
    attr_reader :directories_s, :inherits_s

    def initalize path = nil
        super()
        self.parse path
    end

    def parse path
        super path
        if self.info != nil
            @main = self.get_section('Icon Theme')
            @name = @main['Name']
            @comment = @main['Comment']
            @inherits_s = @main['Inherits', :List]
            @directories_s = @main['Directories', :List]
            @example = @main['Example']
            @directories = self.select{|d| d.head != 'Icon Theme'}.map{|d| IconDirectory.new d}
            @inherits = inherits_s.map{|i| theme_for_name i.strip}
        end
    end

    def icon_search name, size, exts = ['png', 'svg', 'xpm']
        path = File.dirname self.info.path
        dirs = self.directories_s.select{|dir| dir.match %r|#{size}|}
        if name =~ %r|*\.*|
            name, exts = name.split '.'
        else
            exts = exts.join '|'
        end
        for dir in dirs
            Dir.foreach(path + dir) do |file|
                if file =~ %r|#{name}\.#{exts}|
                    return path + dir + file
                end
            end
        end
        return nil
    end

end

def theme_for_name name
    return $ICON_THEMES[name]
end

module IconResolver

    def search_in_pixmaps name, exts = ['png', 'svg', 'xpm']
        path = '/usr/share/pixmaps/'
        exts_p = '\.' + exts.join '|'
        Dir.glob(%r|#{path}#{exts_p}|) do |file|
            if file =~ name
                return file
            end
        end
    end

    def search_in_theme theme, name, size, exts = ['png', 'svg', 'xpm']
        item = theme.find_icon name, size, exts
        if item == nil
            for inherit in theme.inherits
                item = theme.find_icon name, size, exts
                if item == nil 
                    continue
                else
                    return item
                end
            end
        else
            return item
        end
    end

end

$ICON_THEMES = Hash.new
for dir in $CONST['XDG ICON DIRS']
    Dir.foreach(dir) do |file|
        if File.directory? file
            index = File.join(dir, file, 'index.theme')
            if File.exists? index
                theme = IconTheme.new index
                $ICON_THEMES[theme.name] = theme 
            end
        end
    end
end
