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
require './core'
require './constants'
require 'fileutils'


module TRASH
    DATE_FORMAT = '%Y-%d-%mT%H:%M:%S'
    class DIRS
        def self.get
            data = XDG::CONST['XDG DATA HOME'][0]
            trashes = [File.join(data, '/share/Trash'), File.join(data, '/Trash')].select{|d| Dir.exists? d}
            drive_list = all_known_drives # core.rb
            drive_list.each do |drive|
                path = drive + '/.Trash' #this doesn't create directories
                if Dir.exists? path
                    trashes << path
                else
                    path = drive + '/.Trash-' + XDG::CONST::UID
                    if Dir.exists? path
                        trashes << path
                    else
                        path = drive + '/.Trash/' + XDG::CONST::UID
                        trashes << path if Dir.exists? path
                    end 
                end
            end
            return trashes
        end
    end
    def TRASH.time_stamp
        Time.now.strftime('%Y-%d-%mT%H:%M:%S')
    end
end

XDG::CONST['XDG TRASH DIRS'] = TRASH::DIRS.get()

class TrashInfo < IniFile
    attr_reader :main
    attr_reader :original_path, :deletion_date
    def initialize(path = nil)
        super()
        self.parse(path)
    end

    def parse(path)
        ret = super(path)
        return if ret == 0
        if self.info != nil
            @main = self.section('Trash Info')
            @original_path = @main['Path']
            @deletion_date = @main['DeletionDate']
        end
    end
end

class TrashCan
    attr_reader :path, :drive, :info, :files
    attr_reader :time, :last_deleted
    @@time = Proc.new {Time.now.strftime('%Y-%d-%mT%H:%M:%S')}

    def initialize(path)
        @path = path
        @drive = Dir.drivefolder(path)
        @info = File.join(@path, '/info')
        @files = File.join(@path, '/files')
    end

    def accept(file_path)
        @last_deleted = File.new(file_path)
        FileUtils.move(@last_deleted.path, @files)
        t_info = TrashCan.template(@last_deleted.path)
        to_write = File.join(@info, "#{@last_deleted.name}.trashinfo")
        IO.write(to_write, t_info)
    end

    def <<(file_path)
        self.accept(file_path)
    end

    def delete(file_name)
        file = File.join(@files, "#{file_name}")
        info = File.join(@info, "#{file_name}.trashinfo")
        FileUtils.remove_entry(file, force = true)
        FileUtils.remove_entry(info, force = true)
    end; alias :erase :delete

    def restore(file_name)
        file = File.join(@files, file_name)
        info = TrashInfo.new File.join(@info, "#{file_name}.trashinfo")
        FileUtils.move(file, info.original_path)
        begin
            FileUtils.remove_entry(info.info.path, force = true)
        rescue
            raise "No Info File for #{file_name}"
        end
    end

    def contents
        Dir.foreach(@files).map { |name| name}
    end

    def infos
        Dir.foreach(@info).select do |name| 
            name =~ /\w+\.trashinfo/
        end.map do |name|
            TrashInfo.new("#{@info}/#{name}")
        end
    end

    def infos_s
        Dir.foreach(@info).map { |name| name}
    end

    def TrashCan.template(original_path)
        return "[Trash Info]\nPath=#{original_path}\nDeletionDate=#{@@time.call}"
    end
end

class Trash
    def initialize
        @bins = Array.new
        XDG::CONST['XDG TRASH DIRS'].each do |dir|
            @bins << TrashCan.new(dir) 
        end
    end

    def [](drive)
        @bins.each do |bin|
            return bin if bin.drive == drive
        end
    end

    def +(bin)
        @bins << bin if bin.is_a?(TrashCan)
    end

    def each(&pass)
        for bin in @bins
            yield bin
        end
    end

    def accept(file_path)
        bin = self[Dir.drivefolder file_path]
        bin << file_path
        @last_deleted = bin.last_deleted
    end

    def <<(file_path)
        self.accept(file_path)
    end

    def delete(file_name)
        bin = self[Dir.drivefolder file_path]
        bin << file_name
    end; alias :erase :delete

    def restore(file_name)
        bin = self[Dir.drivefolder file_path]
        bin.restore(file_name)
    end

    def contents
        contents = Array.new
        self.each do |bin|
            contents =+ bin.contents
        end
        return contents
    end

    def infos
        infos = Array.new
        self.each do |bin|
            infos =+ bin.infos
        end
        return infos
    end

    def infos_s
        infos_s = Array.new
        self.each do |bin|
            infos_s =+ bin.infos_s
        end
        return infos_s
    end
end

if __FILE__ == $PROGRAM_NAME
    p XDG::CONST['XDG TRASH DIRS']
    trash = TrashCan.new(XDG::CONST['XDG TRASH DIRS'][0])
end