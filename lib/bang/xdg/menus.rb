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

    def MenuParser.configure menu, f
        @menu = menu
        @app_directories = Array.new
        @dir_directories = Array.new
        @merge_directories = Array.new
        self.file(f)
    end

    def parse 
        doc = super
        path = '\Menu\AppDir:\Menu\DirectoryDir:\Menu\MergeDir:\Menu\DefaultAppDirs:\Menu\DefaultDirectoryDirs:\Menu\DefaultMergeDirs'
        doc.find(path).each do |node|
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
            end
        end
        xobj = doc.find_first('\Menu')
        Tools.read_elements @menu, xobj.first, handle_subs = false
        xobj = doc.find('\Menu\Menu')
        xobj.each do |node|
            sub = SubMenu.new
            @menu.submenus << sub
            Tools.read_elements sub, node
        end
    end

    module Tools

        def get_text elem
            elem.children[0].text if node.next?
        end

        def read_elements menu, elem, handle_subs = true
            elem.each_element { |node| 
                case node.name
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
                end                                                 
            }
        end

        def handle_conditions node
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
                        stack.insert pos, [:catagory, Tools.get_text e]
                        pos += 1     
                    end
                    recurse e if e.has_children?
                }
            end
            pos = 0
            recurse node
            return Evaluator.new(stack)
        end 
    end
end

class Evaluator
    attr_reader :node

    def initialize stack
        @node 
    end

    def eval app 
        @node.eval(app)
    end

    def empty?
        return if node == nil
    end
end

class SubMenu
    attr_accessor :name, :layout, :directory, :parent
    attr_accessor :includes, :excludes
    attr_accessor :entries, :submenus
    attr_accessor :only_unallocated, :deleted

    def initalize name = nil, parent
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
        menu = SubMenu.new
        menu.name = @name
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

    def initialize path = nil
        self.parse path
    end

    def parse path
        if path != nil
            @info = File.new path
            @parser = MenuParser.configure(self, path)
            @parser.parse
        end
    end

    def as_submenu
        self.copy
    end
end
