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


XDG::CONST['XDG ICON DIRS'] = XDG::CONST['XDG DATA DIRS'].map{|d| File.join(d, 'icons')} + [File.join(XDG::CONST::HOME, '.icons'), '/usr/share/pixmaps']
XDG::CONST['XDG ICON DIRS'] = XDG::CONST['XDG ICON DIRS'].select {|d| Dir.exists? d}
XDG::CONST['XDG THEME DIRS'] = XDG::CONST['XDG DATA DIRS'].map{|d| File.join(d, 'themes')} + [File.join(XDG::CONST::HOME, '.themes')]
XDG::CONST['XDG THEME DIRS'] = XDG::CONST['XDG ICON DIRS'].select {|d| Dir.exists? d}


class IconDirectory < Section
    attr_reader :size, :context, :type
    attr_reader :min_size, :max_size

    def initialize(section)
        super(section.head, section.fields)
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

    def initialize(path = nil)
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
            @directories = @ini.select{|d| d.head != 'Icon Theme'}.map{|d| IconDirectory.new(d)}
            @inherits = inherits_s.map{|i| IconTheme.by_name i.strip} if !inherits_s.empty?
        end
    end

    def find_icon(name, size, exts = ['png', 'svg', 'xpm'])
        path = File.dirname(@ini.info.path)
        dirs = self.directories_s.select{|dir| dir.match %r|#{size}|}
        if name =~ %r|.*\..+|
            name, exts = name.split '.'
        else
            exts = exts.join '|'
        end
        for dir in dirs
            files = Dir.foreach(File.join(path, dir)).select { |file|
                file =~ %r|#{name}\.(#{exts})|
            }.map{|file| File.join(path, dir, file)}
            if files.empty?
                next
            else
                return files
            end
        end
        return nil
    end

    def self.by_name(name)
        self.new(FileCache.get name)
    end

    def to_s
        return "#{@name}: #{File.dirname @ini.info.path}"
    end

end



module IconResolver

    def self.search_in_pixmaps(name, exts = ['png', 'svg', 'xpm'])
        if name =~ %r|.*\..+|
            name, exts = name.split '.'
        else
            exts = exts.join '|'
        end
        files = Dir.foreach('/usr/share/pixmaps/').select {|file| file =~ /#{name}\.(#{exts})/}
        return files.map {|f| '/usr/share/pixmaps/' + f }
    end

    def self.search_in_theme(theme, name, size, exts = ['png', 'svg', 'xpm'])
        item = theme.find_icon(name, size, exts)
        if item == nil
            for inherit in theme.inherits
                item = theme.find_icon(name, size, exts)
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


module FileCache
    CACHE = Hash.new
    for dir in XDG::CONST['XDG ICON DIRS']
        if Dir.exists? dir
            Dir.foreach(dir) { |file|
                index = File.join(dir, file, 'index.theme')
                if File.exists?(index) && file != 'default'
                    CACHE[file] = index
                end
            }
        end
    end
    def self.get(name)
        var = CACHE[name]
        if var == nil
            CACHE.each { |key, value|
                if key == /#{name}/ix
                    return CACHE[key]
                end
            }
        else
            return var
        end
    end
end


module THEMES
    class ICONS
        DIRS = Hash.new; NAMES = Hash.new
        for dir in XDG::CONST['XDG ICON DIRS']
            if Dir.exists? dir
                Dir.foreach(dir) { |file|
                    index = File.join(dir, file, 'index.theme')
                    if File.exists?(index) && file != 'default'
                        DIRS[file] = IconTheme.new(index)
                    end
                }
            end
        end
        DIRS.each_value { |val|
            NAMES[val.name] = val 
        }

        def ICONS.[](name)
            ret = NAMES[name]
            if ret == nil 
                return DIRS[name]
            else
                return ret
            end
        end
    end
end



if __FILE__ == $PROGRAM_NAME
    p IconResolver.search_in_pixmaps('firefox')
    p THEMES::ICONS['Faenza'].find_icon('firefox', 'scalable', ['svg'])
    # puts 'Name: ' + theme.name
    # puts theme.inherits
    # require 'benchmark'
    # Benchmark.bmbm do |x|
    #     x.report(:init) {
    #         theme = IconTheme.new('/usr/share/icons/HighContrast/index.theme')
    #     }
    #     x.report(:init) {
    #         THEMES::ICONS['gnome']
    #     }
    # end
end