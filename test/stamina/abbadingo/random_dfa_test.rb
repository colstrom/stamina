require 'stamina/stamina_test'
require 'stamina/abbadingo'
module Stamina
  module Abbadingo
    class RandomDFATest < StaminaTest

      def test_it_looks_ok_with_default_options
        dfa = RandomDFA.new(32).execute
        assert dfa.deterministic?
        assert dfa.minimal?
        assert dfa.complete?
      end

    end # class RandomDFATest
  end # module Abbadingo
end # module Stamina
