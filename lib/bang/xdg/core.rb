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

class Dir
    def Dir.walk dir, &block
        root = dir
        dirs, files = []
        Dir.each(dir) do |item|
            if File.directory? item
                dirs << item
            else
                files << item
            end
        end
        block(root, dirs, files)
        dirs.each do |dir|
            Dir.walk(dir, block)
        end
    end

    def walk &block 
        Dir.walk(self.path, block)
    end
end

class String
    # adapted from http://jeffgardner.org/2011/08/04/rails-string-to-boolean-method/
    def to_b
        return true if self == true || self =~ /(true|t|yes|y|1)$/i
        return false if self == false || self.blank? || self =~ /(false|f|no|n|0)$/i
        raise ArgumentError.new("invalid value for Boolean: \"#{self}\"")
    end

    def to_a chars = '|;,'
        return self.split(chars)
    end
end

class Section < Hash
    attr_reader :head
    def initalize name, fields = nil
        super(fields)
        self.default ''
        @head = name
    end

    def [](key, type = nil)
        var = super[key]
        return case type
        when :Int
            var.to_i
        when :Float
            var.to_f
        when :List
            var.to_a
        when :Bool
            var.to_b
        else
            var
        end
    end
end

class IniFile < Array
    attr_reader :info
    def initalize path = nil
        super()
        self.parse path
    end

    def parse path
        if path != nil
            @info = File.new(path)
            @text = IO.read(@info)
            sect = nil
            for line in @text.delete('#.*$').split('\n')
                if (line =~ /\[\.+\]/)
                    if sect != nil self << sect end
                    sect = Section.new(line.delete '[]')
                elsif (line =~ /\w+\=.+/)
                    key, value = line.split('=')
                    sect[key] = value
                end
            end
        end
    end

    def get_section name
        self.each do |section|
            if section.name == name
                return section
            end
        end
    end

    def to_s
       return @text
    end
end
