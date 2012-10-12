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

def env(var, default)
    if ENV.value?(var) and ENV.key?(var)
        item = ENV[var]
        if item.blank?
            return default
        else
            return item.split ':'
        end
    else
        return default
    end
end

$HOME = ENV['HOME']
$UID = %x{id -ur}.delete "\n"

$CONST = Hash['USER HOME' => $HOME, 'USER ID' => $UID]
$CONST['XDG DATA HOME'] = env(var = 'XDG_DATA_HOME', default = [File.join($HOME, '.local')])
$CONST['XDG CONFIG HOME'] = env(var = 'XDG_CONFIG_HOME', default = [File.join($HOME, '.config')])
$CONST['XDG CACHE HOME'] = env(var = 'XDG_CACHE_HOME', default = [File.join($HOME, '.cache')])
$CONST['XDG DATA DIRS'] = env(var ='XDG_DATA_DIRS', default = ['/usr/local/share', '/usr/share'])
$CONST['XDG CONFIG DIRS'] = env(var = 'XDG_CONFIG_DIRS', default = ['/etc/xdg'])

if __FILE__ == $PROGRAM_NAME
    puts $UID
    puts $CONST
end