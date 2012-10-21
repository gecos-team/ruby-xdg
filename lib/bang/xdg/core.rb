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

module Boolean
end

class TrueClass
    include Boolean
end

class FalseClass
    include Boolean
end

def all_known_drives
    lines = %x{mount -v}.split "\n"
    return lines.select{ |p| 
        p.start_with?("/dev/") && !p.include?("/boot")
        }.map {|p| p.slice(0, p.index("t")).split(/\son\s/)[1].strip}
end

class File
    def name(minus = '')
        File.basename self.path, minus
    end

    def dir
        File.dirname self.path
    end

    def ext
        File.basename(self.path).split('.')[-1]
    end
    
end

class Dir
    def Dir.drivefolder(path)
        drives = all_known_drives - ['/']
        drives.each do |drive|
            if path.include?(drive)
                return drive
            else
                return '/' if File.exists?(path)
            end
        end
        return '/' if File.exists?(path)
    end

    def drivefolder
        Dir.drivefolder(self.path)
    end
end

class String
    def blank?
        return self.empty? || self !~ /\S+/ ? true : false 
    end

    # from http://jeffgardner.org/2011/08/04/rails-string-to-boolean-method/
    def to_b
        return true if self == true || self =~ /(true|t|yes|y|1)$/i
        return false if self == false || self.blank? || self =~ /(false|f|no|n|0)$/i
        raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
    end

    def to_a(chars = /\s*[|;,]\s*/)
        return self.split(chars)
    end
end

class Section
    attr_reader :head, :fields
    def initialize(name, fields = Hash.new)
        @fields = fields
        @fields.default = " "
        @head = name
    end

    def [](key, type = nil)
        var = @fields[key]
        return case type
        when :Int
            var == nil ? 0 : var.to_i
        when :Float
            var == nil ? 0.0 : var.to_f
        when :List
            var == nil ? [] : var.strip.to_a
        when :Bool
            var == nil ? false : var.to_b
        else
            var
        end
    end

    def []=(key, value)
        @fields[key] = value
    end 

    def to_s
        "#{@head} #{@fields}"
    end
end

class IniFile
    include Enumerable
    attr_reader :info, :data, :text
    def initialize(path = nil)
        self.parse(path)
    end

    def parse(path)
        if path != nil
            @info = File.new(path)
            @text = IO.read(@info)
            return 0 if @text.blank?
            @data = Array.new
            sect = nil
            for line in @text.delete('#.*$').split(/\n/)
                if (line =~ /^\[.+\]$/)
                    @data << sect if sect != nil
                    sect = Section.new(line.delete '[]')
                elsif (line =~ /.+=.+/)
                    key, value = line.split('=')
                    sect[key] = value
                end
            end
            @data << sect if @data.empty?
        end
    end

    def section(name)
        return if @text.blank?
        if name.instance_of?(String)
            self.each do |section|
                if section.head == name
                    return section
                end
            end
        elsif name.instance_of?(Regexp)
            self.each do |section|
                if section.head =~ name
                    return section
                end
            end
        end       
    end

    def each(&pass)
        return if @text.blank?
        for section in @data 
            yield section
        end
    end

    def to_s
       return @text
    end
end

if __FILE__ == $PROGRAM_NAME
    # ini = IniFile.new('/usr/share/icons/HighContrast/index.theme')
    # sect = ini.section('Icon Theme')
    # puts sect['Directories', :List]
    p Dir.drivefolder('/home/christopher/Documents')
    p Dir.drivefolder('/media/BUFFALO HD/Apps')
end


