module Stamina
  class RegLang
    module Regexp
      include Node

      def to_fa!(fa)
        self.alt.to_fa!(fa)
      end

    end # module Regexp
  end # class RegLang
end # module Stamina