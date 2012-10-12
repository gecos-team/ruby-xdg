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


$CONST['XDG ICON DIRS'] = $CONST['XDG DATA DIRS'].map{|d| File.join(d, 'icons')} + [File.join($HOME, '.icons'), '/usr/share/pixmaps']
$CONST['XDG ICON DIRS'] = $CONST['XDG ICON DIRS'].select {|d| Dir.exists? d}
$CONST['XDG THEME DIRS'] = $CONST['XDG DATA DIRS'].map{|d| File.join(d, 'themes')} + [File.join($HOME, '.themes')]
$CONST['XDG THEME DIRS'] = $CONST['XDG ICON DIRS'].select {|d| Dir.exists? d}

$STD = Hash.new
$STD['STD ICON SIZES'] = %w(16 24 32 36 48 64 72 96 128 160 192 256 scalable)
$STD['STD ICON EXTENSIONS'] = ['png', 'svg', 'xpm']

class IconDirectory < Section
    attr_reader :size, :context, :type
    attr_reader :min_size, :max_size

    def initialize(section)
        super section.head, section
        @size = section['Size']
        @context = section['Context']
        @type = section['Type']
        @min_size = section['MinSize']
        @max_size = section['MaxSize']
    end
end

class IconTheme
    attr_reader :main, :directories, :ini
    attr_reader :name, :comment, :inherits, :example
    attr_reader :directories_s, :inherits_s

    def initialize(path)
        super()
        self.parse(path)
    end

    def parse(path)
        @ini = IniFile.new(path)
        if @ini.info != nil
            @main = @ini.get_section('Icon Theme')
            @name = @main['Name']
            @comment = @main['Comment']
            @inherits_s = @main['Inherits', :List]
            @directories_s = @main['Directories', :List]
            @example = @main['Example']
            @directories = @ini.select{|d| d.head != 'Icon Theme'}.map{|d| IconDirectory.new d}
            @inherits = inherits_s.map{|i| IconTheme.by_name i.strip} if inherits_s != []
        end
    end

    def find_icon(name, size, exts = ['png', 'svg', 'xpm'])
        path = File.dirname(self.info.path)
        dirs = self.directories_s.select{|dir| dir.match %r|#{size}|}
        if name =~ %r|.*\..+|
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

    def self.by_name(name)
        self.new(ICON_THEMES[name])
    end

    def to_s
        return "#{@name}: #{File.dirname @ini.info.path}"
    end

end



module IconResolver

    def search_in_pixmaps(name, exts = ['png', 'svg', 'xpm'])
        path = '/usr/share/pixmaps/'
        exts_p = exts.join '|'
        Dir.glob(%r|#{path}\.#{exts_p}|) do |file|
            if file =~ name; return file; end
        end
    end

    def search_in_theme(theme, name, size, exts = ['png', 'svg', 'xpm'])
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


module ICON_THEMES
    DIRS = Hash.new
    THEMES = Hash.new
    for dir in $CONST['XDG ICON DIRS']
        if Dir.exists? dir
            Dir.foreach(dir) do |file|
                index = File.join(dir, file, 'index.theme')
                if File.exists?(index) && file != 'default'
                    DIRS[file] = index
                    ini = IniFile.new(index)
                    sect = ini.get_section(/Icon Theme|X-GNOME-Metatheme/)
                    THEMES[sect['Name']] = index
                end
            end
        end
    end
    def ICON_THEMES.[](name)
        ret = THEMES[name]
        if ret == nil 
            return DIRS[name]
        else
            return ret
        end
    end
end

if __FILE__ == $PROGRAM_NAME
    puts ICON_THEMES['gnome']
    theme = IconTheme.new('/usr/share/icons/HighContrast/index.theme')
    puts 'Name: ' + theme.name
    puts theme.inherits
end