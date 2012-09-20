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

def env var, default
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
$UID = ENV['UID']

$CONST = Hash['USER_HOME' => $HOME, 'USER_ID' => $UID]
$CONST['XDG_DATA_HOME'] = env 'XDG_DATA_HOME', [File.join($HOME, './local')]
$CONST['XDG_CONFIG_HOME'] = env 'XDG_CONFIG_HOME', [File.join($HOME, './config')]
$CONST['XDG_CACHE_HOME'] = env 'XDG_CACHE_HOME', [File.join($HOME, './cache')]
$CONST['XDG_DATA_DIRS'] = env 'XDG_DATA_DIRS', ['/usr/local/share', '/usr/share']
$CONST['XDG_CONFIG_DIRS'] = env 'XDG_CONFIG_DIRS', ['/etc/xdg']

$STD['ICON_SIZES'] = '16,24,32,36,48,64,72,96,128,160,192,256,scalable'.split(',')
$STD['ICON_EXTENSIONS'] = ['png', 'svg', 'xpm']