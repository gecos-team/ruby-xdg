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

require 'libxml'
require_relative 'applications'
require_relative 'core'

$CONST['XDG MERGE DIRS'] = $CONST['XDG CONFIG DIRS'].map {|d| File.join d, '/menu/applications-merged'}.select{|d| Dir.exists? d}


class MenuParser
    include LibXML
    attr_reader :app_directories, :dir_directories, :merge_directories
    attr_reader :menu

    def initialize(menu)
        @menu = menu
        @app_directories = Array.new
        @dir_directories = Array.new
        @merge_directories = Array.new
    end

    def parse(f)
        doc = XML::Document.file(f)
        read_elements(@menu, doc.root)
    end

    protected
    def read_elements(menu, root)
        root.each_element do |node|
            case node.name
            when 'AppDir'
                @app_directories << node.content
            when 'DirectoryDir'
                @dir_directories << node.content
            when 'MergeDir'
                @merge_directories << node.content
            when 'DefaultAppDirs'
                @app_directories |= $CONST['XDG APP DIRS']
            when 'DefaultDirectoryDirs'
                @dir_directories |= $CONST['XDG DIR DIRS']
            when 'DefaultMergeDirs'
                @merge_directories |= $CONST['XDG MERGE DIRS']
            when 'Name'
                menu.name = node.content
            when 'Directory'
                for dir in @dir_directories
                    if File.exists?(dir + node.content)
                        menu.directory = DesktopEntry.new(node.content)
                    end
                end
            when 'OnlyUnallocated'
                menu.only_unallocated = true
            when 'NotOnlyUnallocated'
                menu.only_unallocated = false
            when 'Deleted'
                menu.deleted = true
            when 'NotDeleted'
                menu.deleted = false
            when 'Include', 'Exclude'
                stack = Array.new(); pos = 0
                recurse = Proc.new do |elem|
                    elem.each_element do |e|
                        arg = e.name.downcase.to_sym
                        case arg
                        when :and, :or, :not
                            stack << [arg, :enter]
                            recurse.call(e)
                            stack << [arg, :exit]
                        when :filename, :category
                            stack << [arg, e.content]
                        end
                    end
                end; recurse.call(node)
                case node.name #revaluating 'when Include, Exclude'
                when 'Include'
                    menu.includes = Cond::Evaluator.new(stack)
                when 'Exclude'
                    menu.excludes = Cond::Evaluator.new(stack)
                end
            when 'MergeFile'
                attrib = node['type']
                p = node.content
                d, f = File.split(p)
                m = Menu.new
                case attrib
                when 'path', nil
                    p = File.join(File.dirname(@menu.info.path), f) if !File.exists?(p)
                when 'parent'
                    @merge_directories.each do |dir|
                        if dir != File.dirname(@menu.info.path)
                            tp = File.join(dir, f)
                            p = tp if File.exists?(tp)
                        end
                    end
                end
                if File.exists? p
                    m.parse p
                    menu.submenus << m.as_submenu
                end
            when 'MergeDir'
                p = node.content
                if !Dir.exists?(p) 
                    dir = File.join(File.dirname menu.info.path, p)
                    if Dir.exists? dir
                        for e in Dir.glob(File.join(dir, '*.menu')) 
                            sub = Menu.new
                            sub.parse e
                            sub = sub.as_submenu
                            menu.submenus << sub
                        end
                    end
                end
            when 'Move'
                @renamer = Renamer.new()
                match = nil; replace = nil 
                node.each_element do |e|
                    case e.name
                    when 'Old'
                        match = e.content
                    when 'New'
                        replace = e.content
                    end
                    if match != nil && replace != nil
                        @renamer[match] = replace
                        match = nil; replace = nil
                    end
                end
            when 'Layout', 'DefaultLayout'
                case node.name
                when 'Layout'
                    layout = Layout.new()
                when 'DefaultLayout'
                    layout = DefaultLayout.new()
                    layout.show_empty = node['show_empty']
                    layout.inline = node['inline']
                    layout.inline_limit = node['inline_limit']
                    layout.inline_header = node['inline_header']
                    layout.inline_alias = node['inline_alias']
                    layout.assign_defaults_if
                end
                node.each_element do |e|
                    case e.name
                    when 'Filename'
                        f = AppCache::APPS[e.content]
                        if f != nil
                            puts f
                            layout.add(DesktopEntry.new f)
                        end
                    when 'Menuname'
                        m = MenuName.new(e.content)
                        m.show_empty = e['show_empty']
                        m.inline = e['inline']
                        m.inline_limit = e['inline_limit']
                        m.inline_header = e['inline_header']
                        m.inline_alias = e['inline_alias']
                        layout.add(m)
                    when 'Merge'
                        layout.add(Merge.new e['type'])
                    when 'Separator'
                        layout.add(Separator.new)
                    end
                end
                menu.layout = layout
            when 'Menu'
                sub = SubMenu.new('', menu)
                menu.submenus << sub
                read_elements(sub, node)
            end
        end
    end

end

module Cond
    class Node 
        attr_reader :parent, :conditions, :children

        def initalize(parent = nil) 
            @parent = parent
            @condition = Array.new
            @children = Array.new
            @parent << self if parent != nil 
        end

        def add_parent(node) 
            @parent = node
            @parent.children << self #make itself the child of the parent 
            return @parent
        end

        def eval(var)
            # unimplemented see subclasses
        end

        def <<(node) 
            @children << node
        end

        def +(cond) 
            @conditions << cond
        end
    end

    class And < Node
        def eval(app)
            bools = Array.new
            if @conditions.empty? 
                bool = false
            else
                @conditions.each do |arg, con|
                    if con == :filename
                        name = File.baseneme(app.info.path)
                        bools << name == arg
                    elsif con == :category
                        bools << app.categories.include?(arg)
                    end
                    bool = !bools.include?(false)
                end
            end
            if @children.empty?
                return bool
            else
                children = Array.new(@children.length) {|i| @children[i].eval(app)}
                child_bool = !children.include?(false)
                return bool && child_bool
            end
        end

    end

    class Or < Node
        def eval(app)
            bools = Array.new
            if @conditions.empty? 
                bool = false
            else
                @conditions.each do |arg, con|
                    if con == :filename
                        name = File.baseneme(app.info.path)
                        bools << name == arg
                    elsif con == :category
                        bools << app.categories.include?(arg)
                    end
                    bool = bools.include?(true)
                end
            end
            if @children.empty?
                return bool
            else
                children = Array.new(@children.length) {|i| @children[i].eval(app)}
                child_bool = children.include?(true)
                return bool || child_bool
            end
        end

    end

    class Not < Node
        def eval(app)
            bools = Array.new
            if @conditions.empty? 
                bool = false
            else
                @conditions.each do |arg, con|
                    if con == :filename
                        name = File.baseneme(app.info.path)
                        bools << name == arg
                    elsif con == :category
                        bools << app.categories.include?(arg)
                    end
                    bool = bools.include?(true)
                end
            end
            if @children.empty?
                return !bool
            else
                children = Array.new(@children.length) {|i| @children[i].eval(app)}
                child_bool = children.include?(true)
                return !bool || child_bool
            end
        end

    end

    class Evaluator
        attr_reader :node, :stack

        def initialize(stack = nil)
            @stack = stack
            if stack != nil
                @node = nil; @stack.each_with_index do |con, arg, index|
                    if arg == :enter
                        if con == :and 
                            @node = @node == nil ? And.new : And.new(@node)
                        elsif con == :or
                            @node = @node == nil ? Or.new : Or.new(@node)
                        elsif con == :not
                            @node = @node == nil ? Not.new : Not.new(@node)
                        end
                    elsif con == :filename || con == :category
                        @node = Or.new() if @node == nil
                        @node + [con, arg]
                    elsif arg == :exit
                        if @node.parent != nil
                            @node = @node.parent
                        else
                            if index != (stack.length - 1)
                                #set the parent and return it
                                @node = @node.add_parent(Or.new)
                            end
                        end
                    end
                end
            end
        end

        def eval(app) 
            @node == nil ? false : @node.eval(app)
        end

        def empty?
            node == nil ? true : false
        end

        def to_s 
            @stack.to_s 
        end
    end
end

<<<<<<< HEAD
class Merge
    attr_accessor :type
    def initialize(type)
        case type
        when 'menus', 'files', 'all'
            @type = type.to_sym
        else
            @type = :all
=======
    module MatchSort
        class Merge
            attr_reader :type
            def initalize(type)
                @type = type
            end
>>>>>>> 3ab63edf7240d4e6a0d9ddaa68addc7593875da9
        end
    end
end

class Separator
    def to_s
        '---------sep---------'
    end
end

module Conditions 
    attr_reader :show_empty
    attr_reader :inline, :inline_limit, :inline_header, :inline_alias

    def show_empty=(show_empty)
        if show_empty == nil || show_empty == ""
            @show_empty = false
        else
            if show_empty.is_a?(String)
                @show_empty = show_empty.to_b
            elsif show_empty.is_a?(Boolean)
                @show_empty = show_empty
            end
        end
    end

    def inline=(inline)
        if inline == nil || inline == ""
            @show_empty = false
        else
            if inline.is_a?(String)
                @inline = inline.to_b
            elsif inline.is_a?(Boolean)
                @inline = inline
            end
        end
    end

    def inline_limit=(inline_limit)
        if inline_limit == nil || inline_limit == ""
            @inline_limit = 4
        else
            if inline_limit.is_a?(String)
                @inline_limit = inline_limit.to_i
            elsif inline_limit.is_a?(Integer)
                @inline_limit = inline_limit
            end
        end
    end

    def inline_header=(inline_header)
        if inline_header == nil || inline_header == ""
            @inline_header = false
        else
            if inline_header.is_a?(String)
                @inline_header = inline_header.to_b
            elsif inline_header.is_a?(Boolean)
                @inline_header = inline_header
            end
        end
    end

    def inline_alias=(inline_alias)
        if inline_alias == nil || inline_alias == ""
            @inline_alias = false
        else
            if inline_alias.is_a?(String)
                @inline_alias = inline_alias.to_b
            elsif inline_alias.is_a?(Boolean)
                @inline_alias = inline_alias
            end
        end
    end

    def assign_defaults_if
        @show_empty = false if @show_empty == nil || @show_empty == ""
        @inline = false if @inline == nil || @inline == ""
        @inline_limit = 4 if @inline_limit == nil || @inline_limit == ""
        @inline_header = false if @inline_header == nil || @inline_header == ""
        @inline_alias = false if @inline_alias == nil || @inline_alias == ""
    end
end

class MenuName
    include Conditions
    attr_accessor :name
    def initialize(name)
        @name = name
    end
end

class Layout 
    include Enumerable
    def initialize(entries = Array.new) 
        @entries = entries
    end

    def add(entry) 
        @entries << entry
    end

    def <<(entry)
        @entries << entry
    end

    def arrange(menu)
        new_menu = Array.new
        @entries.each do |entry|
            if entry.instance_of?(Merge)
                if entry.type == :menus
                    new_menu |= menu.submenus.select{|item| item.is_a?(SubMenu)}
                elsif entry.type == :files
                    new_menu |= menu.submenus.select{|item| item.is_a?(DesktopEntry)}
                elsif entry.type == :all
                    new_menu |= menu.submenus
                end
            elsif entry.instance_of?(MenuName)
                match = nil
                menu.submenus.each do |item|
                    if item.instance_of?(SubMenu) 
                        match = item if item.name == entry.name
                    end
                end
                new_menu << match 
            else
                new_menu << entry #includes DesktopEntries and Seperators
            end
        end
        return new_menu
    end

    def each(&pass)
        for entry in @entries 
            yield entry
        end
    end

    def to_s
        @entries.to_s
    end

end

class DefaultLayout < Layout
    include Conditions
end

class Renamer
    def initialize(data = Hash.new)
        @data = data
    end

    def add(match, replace)
        @data[match] = replace
    end

    def []=(match, replace)
        @data[match] = replace
    end

    def [](old)
        @data[old]
    end

    def rename(string)
        @data.each do |match, replace|
            string.gsub(/#{match}/, replace)
        end
    end
end

class SubMenu
    attr_accessor :name, :layout, :directory, :parent
    attr_accessor :includes, :excludes
    attr_accessor :entries, :submenus
    attr_accessor :only_unallocated, :deleted

    def initialize(name = '', parent = nil)
        @name = name
        @parent = parent
        @submenus = Array.new
        @entries = Array.new
        @only_unallocated = false
        @deleted = false
        @includes = Cond::Evaluator.new 
        @excludes = Cond::Evaluator.new
    end

    def each_entry(&pass)
        for entry in @entries
            yield entry
        end
    end

    def included?(app)
        @includes.eval(app)
    end

    def excluded?(app)
        @excludes.eval(app)
    end

    def copy
        menu = SubMenu.new(@name, @parent)
        menu.layout = @layout
        menu.directory = @directory
        menu.includes = @includes
        menu.excludes = @excludes
        menu.entries = @entries
        menu.submenus = @submenus
        menu.only_unallocated = @only_unallocated
        menu.deleted = @deleted
        return menu
    end

    def to_s
        return "
        Name: #{@name}
        Includes: #{@includes}
        Excludes: #{@excludes}
        Parent: #{@parent.name}
            Submenus: #{@submenus.to_s}
            Entries: #{@entries.to_s}
        "
    end
end

class Menu < SubMenu
    attr_reader :parser, :info

    def initialize(path = nil)
        super()
        self.parse(path) if path != nil
    end

    def parse(path)
        @info = File.new(path)
        @parser = MenuParser.new(self)
        @parser.parse(path)
        self.build()
    end

    def build
        for item in @submenus
            if submenus != nil
                item.submenus = item.submenus.sort{|a, b| a.name <=> b.name}
            end
            if item.layout != nil
                item.entries = item.layout.arrange(self)
            else
                item.entries = item.submenus
            end
            # AppCache.each_app do |app|
            #     if item.included?(app) && !item.excluded?(app)
            #         item.entries << app unless item.entries.include?(app)
            #     end
            # end
        end
        @submenus = @submenus.sort{|a, b| a.name <=> b.name}
        if item.layout != nil
            @entries = @layout.arrange(self)
        else
            @entries = @submenus
        end
    end

    def as_submenu
        self.copy
    end

    def to_s
        return "Name: #{@name}\n"+
        "Includes: #{@includes}\n"+
        "Excludes: #{@excludes}\n"+
        "Layout: #{@layout}\n"+
        "    Submenus: #{@submenus.to_s}\n"+
        "    Entries: #{@entries.to_s}"
    end
end

if __FILE__ == $PROGRAM_NAME
    menu = Menu.new '/etc/xdg/menus/applications.menu'
    puts menu
end
