module AFHBot

    Timer = Struct.new(:name, :attributes, :block) do
      def initialize(name, attributes, block)
        started = Time.new
        super(name, attributes, block)
      end
    end
  
  end