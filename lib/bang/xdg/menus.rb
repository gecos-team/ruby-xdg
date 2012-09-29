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
require 'bang\xdg\applications'
require 'bang\xdg\core'

$CONST['XDG MERGE DIRS'] = $CONST['XDG CONFIG DIRS'].map {|d| File.join d, '/menu/applications-merged'}.select{|d| Dir.exists? d}


module Menus
    class MenuParser < LibXML::XML::Parser
        attr_reader :app_directories, :dir_directories, :merge_directories
        attr_reader :menu

        def Parser.configure(menu, f)
            @menu = menu
            @app_directories = Array.new
            @dir_directories = Array.new
            @merge_directories = Array.new
            self.file(f)
        end

        def parse 
            doc = super
            Tools.read_elements(@menu, doc.root)
        end

        private
        def get_text(elem)
            elem.children[0].text if node.next?
        end

        def read_elements(menu, elem)
            elem.each_element { |node|
                case node.name
                when 'AppDir'
                    @app_directories << self.get_text(node)
                when 'DirectoryDir'
                    @dir_directories << self.get_text(node)
                when 'MergeDir'
                    @merge_directories << self.get_text(node)
                when 'DefaultAppDirs'
                    @app_directories |= $CONST['XDG APP DIRS']
                when 'DefaultDirectoryDirs'
                    @dir_directories |= $CONST['XDG DIR DIRS']
                when 'DefaultMergeDirs'
                    @merge_directories |= $CONST['XDG MERGE DIRS']
                when 'Name'
                    menu.name = self.get_text(node)
                when 'Directory'
                    menu.directory = DesktopEntry.new(self.get_text node)
                when 'OnlyUnallocated'
                    menu.only_unallocated = true
                when 'NotOnlyUnallocated'
                    menu.only_unallocated = false
                when 'Deleted'
                    menu.deleted = true
                when 'NotDeleted'
                    menu.deleted = false
                when 'Include', 'Exclude'
                    stack = Array.new()
                    def recurse elem
                        elem.each_element { |e|
                            case e.name
                            when 'And'
                                stack.insert pos, [:and, :enter]
                                stack.insert pos, [:and, :exit]
                                pos = stack.lenth - 1
                            when 'Or'
                                stack.insert pos, [:or, :enter]
                                stack.insert pos, [:or, :exit]
                                pos = stack.lenth - 1
                            when 'Not'
                                stack.insert pos, [:not, :enter]
                                stack.insert pos, [:not, :exit]
                                pos = stack.lenth - 1
                            when 'Filename'
                                stack.insert pos, [:file, self.get_text e]
                                pos += 1
                            when 'Category'
                                stack.insert pos, [:category, self.get_text e]
                                pos += 1     
                            end
                            recurse e if e.has_children?
                        }
                    end; pos = 0; recurse(node)
                    case node.name #revaluating 'when Include, Exclude'
                    when 'Include'
                        menu.includes = Cond::Evaluator.new(stack)
                    when 'Exclude'
                        menu.excludes = Cond::Evaluator.new(stack)
                    end
                when 'MergeFile'
                    attrib = node['type']
                    p = self.get_text(node)
                    d, f = File.split(p)
                    m = Menu.new
                    case attrib
                    when 'path', attrib.blank?
                        p = File.join(File.dirname menu.info.path, f) if !File.exists?(p)
                    when 'parent'
                        @merge_directories.each { |dir|
                            if dir != File.dirname(menu.info.path)
                                tp = File.join(dir, f)
                                p = tp if File.exists?(tp)
                            end
                        }
                    end
                    if File.exists? p
                        m.parse p
                        menu.submenus << m.as_submenu
                    end
                when 'MergeDir'
                    p = self.get_text(node)
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
                    @renamer = MatchSort::Renamer.new()
                    match = nil; replace = nil 
                    node.each_element { |e|
                        case e.name
                        when 'Old'
                            match = self.get_text(e)
                        when 'New'
                            replace = self.get_text(e)
                        end
                        if match != nil && replace != nil
                            @renamer[match] = replace
                            match = nil; replace = nil
                        end
                    }
                when 'Layout', 'DefaultLayout'
                    case node.name
                    when 'Layout'
                        layout = MatchSort::Layout.new()
                    when 'DefaultLayout'
                        layout = MatchSort::DefaultLayout.new()
                        layout.show_empty = node['show_empty'].to_b
                        layout.inline = node['inline'].to_i
                        layout.inline_limit = node['inline_limit'].to_i
                        layout.inline_header = node['inline_header'].to_b
                        layout.inline_alias = node['inline_alias'].to_b
                    end
                    node.each_element { |e|
                        case node.name
                        when 'Filename'
                            f = $APPS[self.get_text e]
                            if f != nil 
                                layout.add(f)
                            end
                        when 'MenuName'
                            m = MatchSort::MenuName.new()
                            m.show_empty = node['show_empty'].to_b
                            m.inline = node['inline'].to_i
                            m.inline_limit = node['inline_limit'].to_i
                            m.inline_header = node['inline_header'].to_b
                            m.inline_alias = node['inline_alias'].to_b
                            layout.add(m)
                        when 'Merge'
                            layout.add(Merge.new node['type'])
                        when 'Separator'
                            layout.add(Separator.new)
                        end        
                    }
                    menu.layout = layout
                when 'Menu'
                    sub = SubMenu.new
                    menu.submenus << sub
                    self.read_elements(sub, node)
                end
            }
        end

        def handle_conditions(node)
            stack = Array.new()
            def recurse elem
                elem.each_element { |e|
                    case e.name
                    when 'And'
                        stack.insert pos, [:and, :enter]
                        stack.insert pos, [:and, :exit]
                        pos = stack.lenth - 1
                    when 'Or'
                        stack.insert pos, [:or, :enter]
                        stack.insert pos, [:or, :exit]
                        pos = stack.lenth - 1
                    when 'Not'
                        stack.insert pos, [:not, :enter]
                        stack.insert pos, [:not, :exit]
                        pos = stack.lenth - 1
                    when 'Filename'
                        stack.insert pos, [:file, self.get_text e]
                        pos += 1
                    when 'Category'
                        stack.insert pos, [:category, self.get_text e]
                        pos += 1     
                    end
                    recurse e if e.has_children?
                }
            end
            pos = 0
            recurse(node)
            return Cond::Evaluator.new(stack)
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

            def parent=(node) 
                @parent = node
                @parent.children << self
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
                    @conditions.each { |arg, con|
                        if con == :file
                            name = File.baseneme(app.info.path)
                            bools << name == arg
                        elsif con == :category
                            bools << app.categories.include? arg
                        end
                        bool = !bools.include? false
                    }
                end
                if @children.empty?
                    return bool
                else
                    children = Array.new(@children.length) {|i| @children[i].eval(app)}
                    child_bool = !children.include? false
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
                    @conditions.each { |arg, con|
                        if con == :file
                            name = File.baseneme(app.info.path)
                            bools << name == arg
                        elsif con == :category
                            bools << app.categories.include? arg
                        end
                        bool = bools.include? true
                    }
                end
                if @children.empty?
                    return bool
                else
                    children = Array.new(@children.length) {|i| @children[i].eval(app)}
                    child_bool = children.include? true
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
                    @conditions.each { |arg, con|
                        if con == :file
                            name = File.baseneme(app.info.path)
                            bools << name == arg
                        elsif con == :category
                            bools << app.categories.include? arg
                        end
                        bool = bools.include? true
                    }
                end
                if @children.empty?
                    return !bool
                else
                    children = Array.new(@children.length) {|i| @children[i].eval(app)}
                    child_bool = children.include? true
                    return !bool || child_bool
                end
            end

        end

        class Evaluator
            attr_reader :node, :stack

            def initialize(stack = nil)
                @stack = stack
                if stack != nil
                    @node = nil; @stack.each_with_index { |con, arg, index|
                        if arg == :enter
                            if con == :and 
                                @node = @node == nil ? And.new : And.new(@node)
                            elsif con == :or
                                @node = @node == nil ? Or.new : Or.new(@node)
                            elsif con == :not
                                @node = @node == nil ? Not.new : Not.new(@node)
                            end
                        elsif con == :file || con == :category
                            @node = Or.new() if @node == nil
                            @node + [con, arg]
                        elsif arg == :exit
                            if @node.parent != nil
                                @node = @node.parent
                            else
                                if index != (stack.length - 1)
                                    @node = @node.parent Or.new
                                end
                            end
                        end
                    }
                end
            end

            def eval(app) 
                @node.eval(app)
            end

            def empty?
                node == nil ? false : true
            end

            def to_s 
                @stack.to_s 
            end
        end
    end

    module MatchSort
        class Merge
        end

        class Seperator
            def to_s
                '---------sep---------'
            end
        end

        module Conditions 
            attr_reader :show_empty
            attr_reader :inline, :inline_limit, :inline_header, :inline_alias
        end

        class MenuName
            include Conditions
        end

        class DefaultLayout < Layout
            include Conditions
        end

        class Layout
        end

        class Renamer
            def initialize(data)
                @data = Hash.new
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

    end
end

class SubMenu
    attr_accessor :name, :layout, :directory, :parent
    attr_accessor :includes, :excludes
    attr_accessor :entries, :submenus
    attr_accessor :only_unallocated, :deleted

    def initalize(name = nil, parent = nil)
        @name = name
        @parent = parent
        @submenus = Array.new
        @entries = Array.new
        @only_unallocated = false
        @deleted = false
        @includes = Evaluator.new 
        @excludes = Evaluator.new
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
end

class Menu < SubMenu
    attr_reader :parser, :info

    def initialize(path = nil)
        self.parse(path) if path != nil
    end

    def parse path
        @info = File.new path
        @parser = Menus::MenuParser.configure(self, path)
        @parser.parse
    end

    def as_submenu
        self.copy
    end
end
