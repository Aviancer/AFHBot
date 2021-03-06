module AFHBot

  Command = Struct.new(:name, :attributes, :block) do
    def initialize(name, attributes, block)
      super(name, attributes, block)
    end
  end

end
