#!/usr/bin/env ruby

# Copyright (c) 2012, Christopher L. Ramsey <christopherlramsey@gmx.us>
# All rights reserved.

# Redistribution and use in source and binary forms, with or without modification,
# are permitted provided that the following conditions are met: Redistributions of
# source code must retain the above copyright notice, this list of conditions and
# the following disclaimer. Redistributions in binary form must reproduce the
# above copyright notice, this list of conditions and the following disclaimer in
# the documentation and/or other materials provided with the distribution.

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

require 'core'

class IconDirectory < Section
    attr_reader :size, :context, :type
    attr_reader :min_size, :max_size

    def initalize section
        super section.name, section.fields
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
end
