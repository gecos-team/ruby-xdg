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

module Bang
    module DBusSettings
        SYSTEM_BUS = 'system-bus'
        SESSION_BUS = 'session-bus'
        @@connection_type = nil
        @@service = String.new
        def bus=(connection)
            @@connection_type = connection
        end
        def service=(service)
            @@service = service
        end
    end

    class DBusClient
        merge_with(DBusSettings)
        attr_reader :objects, :service
        def initialize
            case @@connection_type
            when SESSION_BUS
                @bus = DBus::SessionBus.instance
            when SYSTEM_BUS
                @bus = DBus::SystemBus.instance    
            end
            @service = @bus.service(@@service)
            @service.introspect
            @objects = self.make_paths(@service.root)
        end

        def reflect(name)
            ReflectedObject.new(self[name])
        end

        def [](name)
            @objects.each_key do |path|
                base = File.basename(path)
                return @objects[path] if path == name || base.include?(name)
            end
        end

        protected
        def make_paths(root)
            paths = Hash.new
            recurse = Proc.new do |hashes|
                hashes.each_pair do |k, v|
                    if v.is_a?(DBus::Node)
                        obj = v.object
                        if obj != nil
                            paths[obj.path] = obj
                        end
                        recurse.call(v)
                    end
                end
            end
            recurse.call(root)
            return paths
        end
        class ReflectedObject
            attr_reader :obj, :interfaces
            def initialize(obj)
                @obj = obj
                @interfaces = @obj.interfaces.map{|i| obj[i]}
            end
            def get(prop)
                intf = @interfaces.select{|i| i[prop.to_s] != nil}[-1]
                intf[prop.to_s]
            end; alias :[] :get

            def set(prop, val)
                intf = @interfaces.select{|i| i[prop.to_s] != nil}[-1]
                intf[prop.to_s] = val
            end; alias :[]= :set

            def call(funct, *args)
                intf = @interfaces.select{|i| i.methods.include? funct.to_s}[-1]
                intf.send(funct.to_sym, *args)
            end
        end
    end
end

if __FILE__ == $PROGRAM_NAME
    class Test < Bang::DBusClient
        self.bus = Bang::DBusSettings::SYSTEM_BUS
        self.service = "org.freedesktop.UPower"
    end
    test = Test.new
    batt = test.reflect('battery_BAT1')
    p batt.call(:GetAll, "org.freedesktop.UPower.Device")
    p batt.get(:Vendor)
    # this still works
    # test.objects.each do |k, v|
    #     p "#{k} #{v}"
    # end
    # obj = test.objects['/org/freedesktop/UPower/battery_BAT1']
    # puts "OBJECT: #{obj.inspect}"
end