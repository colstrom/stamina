require 'stamina_test'
module Stamina
  class SampleTest < StaminaTest

    # Converts a String to an InputString
    def s(str)
      Stamina::ADL::parse_string(str)
    end

    # Tests Sample#empty?
    def test_empty
      assert_equal(true, Sample.new.empty?)
      assert_equal(true, Sample[].empty?)
      assert_equal(false, Sample['?'].empty?)
      assert_equal(false, Sample['-'].empty?)
      assert_equal(false, Sample['+'].empty?)
      assert_equal(false, Sample['+ a b'].empty?)
      assert_equal(false, Sample['+ a b', '- a'].empty?)
      assert_equal(false, Sample['- a b'].empty?)
    end

    # Tests Sample#size
    def test_size_and_counts
      s = Sample.new
      assert_equal(0, s.size)
      assert_equal(0, s.positive_count)
      assert_equal(0, s.negative_count)
      s << '+ a b'
      assert_equal(1, s.size)
      assert_equal(1, s.positive_count)
      assert_equal(0, s.negative_count)
      s << '+ a b'
      assert_equal(2, s.size)
      assert_equal(2, s.positive_count)
      assert_equal(0, s.negative_count)
      s << '+ a'
      assert_equal(3, s.size)
      assert_equal(3, s.positive_count)
      assert_equal(0, s.negative_count)
      s << '- a b c'
      assert_equal(4, s.size)
      assert_equal(3, s.positive_count)
      assert_equal(1, s.negative_count)
    end

    def test_same_string_can_be_added_many_times
      s = Sample.new
      10.times {|i| s << "+ a b"}
      assert_equal(10, s.size)
      assert_equal(10, s.positive_count)
      assert_equal(0, s.negative_count)
      strings = s.collect{|s| s}
      assert_equal 10, strings.size
    end

    # Tests Sample#<<
    def test_append
      s = Sample.new
      assert_equal(s,s << '+',"Accepts empty string")
      assert_equal(s,s << '+ a b a b a',"Accepts positive string")
      assert_equal(s,s << '- a',"Accepts negative string")
      assert_equal(s,s << '? a',"Accepts unlabeled string")
    end

    # Tests Sample#include? on every kind of arguments it announce
    def test_append_accepts_arguments_it_annouce
      expected = Sample[
        '+ a b a b',
        '+ a b',
        '-',
        '- a',
        '+ a b a b a b'
      ]
      s = Sample.new
      s << '+ a b a b'
      s << ['+ a b', '-']
      s << InputString.new('a', false)
      s << Sample['+ a b a b a b', '-']
      assert_equal(expected,s)
    end

    # Tests that Sample#<< detects inconsistencies
    # def test_append_detects_inconsistency
    #   s = Sample.new
    #   s << '+ a b'
    #   s << '+ a b a b'
    #   assert_raise InconsistencyError do
    #     s << '- a b a b'
    #   end
    # end

    # Tests that Sample#<< detects inconsistencies
    def test_append_detects_real_inconsistencies_only
      s = Sample.new
      s << '+ a b'
      s << '+ a b a b'
      assert_nothing_raised do
        s << '- b'
        s << '- a'
        s << '- a b a'
      end
    end

    # Tests each
    def test_each
      strings = ['+ a b a b', '+ a b', '+ a b', '- a', '+']
      strings = strings.collect{|s| ADL::parse_string(s)}
      s = Sample.new << strings
      count = 0
      s.each do |str|
        assert_equal(true, strings.include?(str))
        count += 1
      end
      assert_equal(strings.size, count)
    end

    # Tests each_positive
    def test_each_positive
      sample = Sample[
        '+',
        '- b',
        '+ a b a b',
        '- a b a a'
      ]
      count = 0
      sample.each_positive do |str|
        assert str.positive?
        count += 1
      end
      assert_equal 2, count
      positives = sample.positive_enumerator.collect{|s| s}
      assert_equal 2, positives.size
      [s('+'), s('+ a b a b')].each do |str|
        assert positives.include?(str)
      end
    end

    # Tests each_negative
    def test_each_negative
      sample = Sample[
        '+',
        '- b',
        '+ a b a b',
        '- a b a a'
      ]
      count = 0
      sample.each_negative do |str|
        assert str.negative?
        count += 1
      end
      assert_equal 2, count
      negatives = sample.negative_enumerator.collect{|s| s}
      assert_equal 2, negatives.size
      [s('- b'), s('- a b a a')].each do |str|
        assert negatives.include?(str)
      end
    end

    # Tests Sample#include?
    def test_include
      strings = ['+ a b a b', '+ a b', '- a', '+']
      s = Sample.new << strings
      strings.each do |str|
        assert_equal(true, s.include?(str))
      end
      assert_equal(true, s.include?(strings))
      assert_equal(true, s.include?(s))
      assert_equal(false, s.include?('+ a'))
      assert_equal(false, s.include?('-'))
      assert_equal(false, s.include?('+ a b a'))
    end

    # Tests Sample#include? on every kind of arguments it announce
    def test_include_accepts_arguments_it_annouce
      s = Sample.new << ['+ a b a b', '+ a b', '- a', '+']
      assert_equal true, s.include?('+ a b a b')
      assert_equal true, s.include?(InputString.new('a b a b',true))
      assert_equal true, s.include?(ADL::parse_string('+ a b a b'))
      assert_equal true, s.include?(['+ a b a b', '+ a b'])
      assert_equal true, s.include?(s)
    end

    # Tests Sample#==
    def test_equal
      s1 = Sample['+ a b a b', '+', '- a']
      s2 = Sample['+ a b a b', '+', '+ a']
      assert_equal(true, s1==s1)
      assert_equal(true, s2==s2)
      assert_equal(false, s1==s2)
      assert_equal(false, s1==Sample.new)
      assert_equal(false, s2==Sample.new)
    end

    # Test the signature
    def test_signature
      s = Sample.new
      assert_equal '', s.signature
      s = Sample.new << ['+ a b a b', '+ a b', '- a', '+']
      assert_equal '1101', s.signature
      s = Sample.new << ['+ a b a b', '+ a b', '- a', '?']
      assert_equal '110?', s.signature
      s = Stamina::ADL.parse_sample <<-SAMPLE
        +
        + a b
        - a c
        ? a d
      SAMPLE
      assert_equal '110?', s.signature
    end

    def test_to_pta_on_empty_sample
      empty = Stamina::ADL::parse_automaton <<-EOF
        1 0
        0 true false
      EOF
      assert_equivalent empty, Sample.new.to_pta
    end

    def test_to_pta_on_lambda_accepting_sample
      dfa = Stamina::ADL::parse_automaton <<-EOF
        1 0
        0 true true false
      EOF
      sample = Stamina::ADL::parse_sample <<-EOF
        +
      EOF
      assert_equivalent dfa, sample.to_pta
    end

    def test_to_pta_on_lambda_rejecting_sample
      dfa = Stamina::ADL::parse_automaton <<-EOF
        1 0
        0 true false true
      EOF
      sample = Stamina::ADL::parse_sample <<-EOF
        -
      EOF
      assert_equivalent dfa, sample.to_pta
    end

    def test_to_pta_respects_natural_ordering
      dfa = Stamina::ADL::parse_automaton <<-EOF
        3 2
        0 true false
        1 false true
        2 false true
        0 1 a
        0 2 b
      EOF
      sample = Stamina::ADL::parse_sample <<-EOF
        + a
        + b
      EOF
      pta = sample.to_pta
      assert_equivalent dfa, pta
      assert_equal pta.ith_state(1), pta.dfa_reached("? a")
      assert_equal pta.ith_state(2), pta.dfa_reached("? b")
    end

    def test_to_pta_on_realcase_example
      dfa = Stamina::ADL::parse_automaton <<-EOF
        5 4
        0 true true
        1 false true
        2 false false true
        3 false false true
        4 false true
        0 1 a
        0 2 b
        1 3 b
        2 4 a
      EOF
      sample = Stamina::ADL::parse_sample <<-EOF
        +
        + a
        + b a
        - a b
        - b
      EOF
      pta = sample.to_pta
      assert_equivalent dfa, pta
      assert_equal pta.ith_state(3), pta.dfa_reached("? a b")
      assert_equal pta.ith_state(4), pta.dfa_reached("? b a")
    end

    def test_union
      s1 = Sample.parse <<-EOF
        + a
        + c
      EOF
      s2 = Sample.parse <<-EOF
        + a
        - b
      EOF
      expected = Sample.parse <<-EOF
        + a
        + c
        - b
      EOF
    end

  end # class SampleTest
end # module Stamina