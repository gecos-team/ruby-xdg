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


class MenuParser < LibXML::XML::Parser
    attr_reader :app_directories, :dir_directories, :merge_directories
    attr_reader :menu

    def MenuParser.configure(menu, f)
        @menu = menu
        @app_directories = Array.new
        @dir_directories = Array.new
        @merge_directories = Array.new
        self.file(f)
    end

    def parse 
        doc = super
        doc.root.each_element { |node|
            case node.name
            when 'AppDir'
                @app_directories << Tools.get_text node
            when 'DirectoryDir'
                @dir_directories << Tools.get_text node
            when 'MergeDir'
                @merge_directories << Tools.get_text node
            when 'DefaultAppDirs'
                @app_directories |= $CONST['XDG APP DIRS']
            when 'DefaultDirectoryDirs'
                @dir_directories |= $CONST['XDG DIR DIRS']
            when 'DefaultMergeDirs'
                @merge_directories |= $CONST['XDG MERGE DIRS']
            when 'Name'
                menu.name = self.get_text node
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
                conditions = Tools.handle_conditions node
                case node.name
                when 'Include'
                    menu.includes = conditions
                when 'Exclude'
                    menu.excludes = conditions                    
                end
            when ''
            end
        }
    end

    module Tools

        def get_text(elem)
            elem.children[0].text if node.next?
        end

        def handle_conditions(node)
            stack = Array.new()
            def recurse elem
                elem.each_element { |e|
                    case e.name
                    when 'And'
                        stack << [:and, :enter]
                        stack << [:and, :exit]
                        pos = stack.lenth - 1
                    when 'Or'
                        stack << [:or, :enter]
                        stack << [:or, :exit]
                        pos = stack.lenth - 1
                    when 'Not'
                        stack << [:not, :enter]
                        stack << [:not, :exit]
                        pos = stack.lenth - 1
                    when 'Filename'
                        stack.insert pos, [:file, Tools.get_text e]
                        pos += 1
                    when 'Category'
                        stack.insert pos, [:category, Tools.get_text e]
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
end

module Cond
    class Node 
        attr_reader :parent, :conditions, :children

        def initalize(parent = nil) 
            @parent = parent
            @condition = Array.new
            @children = Array.new
            @parent.children << self if parent != nil 
        end

        def parent=(node) 
            @parent = node
            @parent.children << self
            return @parent
        end

        def <<(con, arg) 
            @conditions << [con, arg]
        end
    end

    class Evaluator
        attr_reader :node, :stack

        def initialize(stack)
            @stack = stack
            @node = nil
            @stack.each_with_index { |con, arg, index|
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
                    @node << con, arg
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

        def eval(app) 
            @node.eval(app)
        end

        def empty?
            return node == nil ? true : false
        end

        def to_s 
            return @stack.to_s 
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
        menu = SubMenu.new @name, @parent
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
        @parser = MenuParser.configure(self, path)
        @parser.parse
    end

    def as_submenu
        self.copy
    end
end
