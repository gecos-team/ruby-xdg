class Section < Hash
    attr_reader :name
    def initalize name, fields = nil
        super(fields)
        @name = name
    end

    def get_as key, type, default
        var = self[key]
    end
end

class IniFile
    def initalize path
        @text = IO.read File.new(path)
        for line in @text.split('\n')
            if (line =~ /\[\w+\]/)
                
            end
        end
    end

    def get_section name
    end

    def to_s
       return @text
    end
end
