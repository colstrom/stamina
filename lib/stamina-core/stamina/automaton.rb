require_relative 'automaton/state'
require_relative 'automaton/edge'
module Stamina
  #
  # Automaton data-structure.
  #
  # == Examples
  # The following example uses a lot of useful DRY shortcuts, so, if it does not
  # fit you needs then, read on!):
  #
  #     # Building an automaton for the regular language a(ba)*
  #     fa = Automaton.new do
  #       add_state(:initial => true)
  #       add_state(:accepting => true)
  #       connect(0,1,'a')
  #       connect(1,0,'b')
  #     end
  #
  #     # It accepts 'a b a b a', rejects 'a b' as well as ''
  #     puts fa.accepts?('? a b a b a')   # prints true
  #     puts fa.accepts?('? a b')         # prints false
  #     puts fa.rejects?('?')            # prints true
  #
  # == Four things you need to know
  # 1. Automaton, State and Edge classes implement a Markable design pattern, that
  #    is, you can read and write any key/value pair you want on them using the []
  #    and []= operators. Note that the following keys are used by Stamina itself,
  #    with the obvious semantics (for automata and transducers):
  #    - <tt>:initial</tt>, <tt>:accepting</tt>, <tt>:error</tt> on State;
  #      expected to be _true_ or _false_ (_nil_ and ommitted are considered as false).
  #      Shortcuts for querying and setting these attributes are provided by State.
  #    - <tt>:symbol</tt> on Edge, with shortcuts as well on Edge.
  #      The convention is to use _nil_ for the epsilon symbol (aka non observable)
  #      on non deterministic automata.
  #    The following keys are reserved for future extensions:
  #    - <tt>:output</tt> on State and Edge.
  #    - <tt>:short_prefix</tt> on State.
  #    See also the "About states and edges" subsection of the design choices.
  # 2. Why using State methods State#step and State#delta ? The Automaton class includes
  #    the Walking module by default, which is much more powerful !
  # 3. The constructor of this class executes the argument block (between <tt>do</tt>
  #    and <tt>end</tt>) with instance_eval by default. You won't be able to invoke
  #    the methods defined in the scope of your block in such a case. See new
  #    for details.
  # 4. This class has not been designed with efficiency in mind. If you experiment
  #    performance problems, read the "About Automaton modifications" sub section
  #    of the design choices.
  #
  # == Design choices
  # This section fully details the design choices that has been made for the
  # implementation of the Automaton data structure used by Stamina. It is provided
  # because Automaton is one of the core classes of Stamina, that probably all
  # users (and contributors) will use. Automaton usage is really user-friendly,
  # so <b>you are normally not required</b> to read this section in the first
  # place ! Read it only if of interest for you, or if you experiment unexpected
  # results.
  #
  # === One Automaton class only
  # One class only implements all kinds of automata: deterministic, non-deterministic,
  # transducers, prefix-tree-acceptors, etc. The Markable design pattern on states and
  # edges should allow you to make anything you could find useful with this class.
  #
  # === Adjacency-list graph
  # This class implements an automaton using a adjacent-list graph structure.
  # The automaton has state and edge array lists and exposes them through the
  # _states_ and _edges_ accessors. In order to let users enjoy the enumerability
  # of Ruby's arrays while allowing automata to be modified, these arrays are
  # externaly modifiable. However, <b>users are not expected to modify them!</b>
  # and future versions of Stamina will certainly remove this ability.
  #
  # === Indices exposed
  # State and Edge indices in these arrays are exposed by this class. Unless stated
  # explicitely, all methods taking state or edge arguments support indices as well.
  # Moreover, ith_state, ith_states, ith_edge and ith_edges methods provide powerful
  # access to states and edges by indices. All these methods are robust to invalid
  # indices (and raise an IndexError if incorrectly invoked) but do not allow
  # negative indexing (unlike ruby arrays).
  #
  # States and edges know their index in the corresponding array and expose them
  # through the (read-only) _index_ accessor. These indices are always valid;
  # without deletion of states or edges in the automaton, they are guaranteed not
  # to change. Indices saved in your own variables must be considered deprecated
  # each time you perform a deletion ! That's the only rule to respect if you plan
  # to use indices.
  #
  # Indices exposition may seem a strange choice and could be interpreted as
  # breaking OOP's best practice. You are not required to use them but, as will
  # quiclky appear, using them is really powerful and leads to beautiful code!
  # If you don't remove any state or edge, this class guarantees that indices
  # are assigned in the same order as invocations of add_state and add_edge (as
  # well as their plural forms and aliases).
  #
  # === About states and edges
  # Edges know their source and target states, which are exposed through the
  # _source_ and _target_ (read-only) accessors (also aliased as _from_ and _to_).
  # States keep their incoming and outgoing edges in arrays, which are accessible
  # (in fact, a copy) using State#in_edges and State#out_edges. If you use them
  # for walking the automaton in a somewhat standard way, consider using the Walking
  # module instead!
  #
  # Common attributes of states and edges are installed using the Markable pattern
  # itself:
  # - <tt>:initial</tt>, <tt>:accepting</tt> and <tt>:error</tt> on states. These
  #   attributes are expected to be _true_ or _false_ (_nil_ and ommitted are also
  #   supported and both considered as false).
  # - <tt>:symbol</tt> on edges. Any object you want as long as it responds to the
  #   <tt><=></tt> operator. Also, the convention is to use _nil_ for the epsilon
  #   symbol (aka non observable) on non deterministic automata.
  #
  # In addition, useful shortcuts are available:
  # - <tt>s.initial?</tt> is a shortcut for <tt>s[:initial]</tt> if _s_ is a State
  # - <tt>s.initial!</tt> is a shortcut for <tt>s[:initial]=true</tt> if _s_ is a State
  # - Similar shortcuts are available for :accepting and :error
  # - <tt>e.symbol</tt> is a shortcut for <tt>e[:symbol]</tt> if _e_ is an Edge
  # - <tt>e.symbol='a'</tt> is a shortcut for <tt>e[:symbol]='a'</tt> if _e_ is an Edge
  #
  # Following keys should be considered reserved by Stamina for future extensions:
  # - <tt>:output</tt> on State and Edge.
  # - <tt>:short_prefix</tt> on State.
  #
  # === About Automaton modifications
  # This class has not been implemented with efficiency in mind. In particular, we expect
  # the vast majority of Stamina core algorithms considering automata as immutable values.
  # For this reason, the Automaton class does not handle modifications really efficiently.
  #
  # So, if you experiment performance problems, consider what follows:
  # 1. Why updating an automaton ? Building a fresh one is much more clean and efficient !
  #    This is particularly true for removals.
  # 2. If you can create multiples states or edges at once, consider the plural form
  #    of the modification methods: add_n_states and drop_states. Those methods are
  #    optimized for multiple updates.
  #
  # == Detailed API
  class Automaton
    include Stamina::Markable

    ### Automaton class ##########################################################
    public

    # State list and edge list of the automaton
    attr_reader :states, :edges

    #
    # Creates an empty automaton and executes the block passed as argument. The _onself_
    # argument dictates the way _block_ is executed:
    # - when set to false, the block is executed traditionnally (i.e. using yield).
    #   In this case, methods invocations must be performed on the automaton object
    #   passed as block argument.
    # - when set to _true_ (by default) the block is executed in the context of the
    #   automaton itself (i.e. with instance_eval), allowing call of its methods
    #   without prefixing them by the automaton variable. The automaton still
    #   passes itself as first block argument. Note that in this case, you won't be
    #   able to invoke a method defined in the scope of your block.
    #
    # Example:
    #   # The DRY way to do:
    #   Automaton.new do |automaton|     # automaton will not be used here, but it is passed
    #     add_state(:initial => true)
    #     add_state(:accepting => true)
    #     connect(0, 1, 'a')
    #     connect(1, 0, 'b')
    #
    #     # method_in_caller_scope()     # commented because not allowed here !!
    #   end
    #
    #   # The other way:
    #   Automaton.new(false) do |automaton|      # automaton MUST be used here
    #     automaton.add_state(:initial => true)
    #     automaton.add_state(:accepting => true)
    #     automaton.connect(0, 1, 'a')
    #     automaton.connect(1, 0, 'b')
    #
    #     method_in_caller_scope()               # allowed in this variant !!
    #   end
    #
    def initialize(onself=true, &block) # :yields: automaton
      @states = []
      @edges = []
      @initials = nil
      @alphabet = nil
      @deterministic = nil

      # if there's a block, execute it now!
      if block_given?
        if onself
          if RUBY_VERSION >= "1.9.0"
            instance_exec(self, &block)
          else
            instance_eval(&block)
          end
        else
          block.call(self)
        end
      end
    end

    # Coerces `arg` to an automaton
    def self.coerce(arg)
      if arg.respond_to?(:to_fa)
        arg.to_fa
      elsif arg.is_a?(String)
        parse(arg)
      else
        raise ArgumentError, "Invalid argument #{arg} for `Automaton`"
      end
    end

    # Parses an automaton using ADL
    def self.parse(str)
      ADL::parse_automaton(str)
    end

    ### public read-only section #################################################
    public

    # Returns a symbols comparator taking epsilon symbols into account. Comparator
    # is provided as Proc instance which is a lambda function.
    def symbols_comparator
      @symbols_comparator ||= Kernel.lambda do |a,b|
        if a==b then 0
        elsif a.nil? then -1
        elsif b.nil? then 1
        else a <=> b
        end
      end
    end

    # Returns the number of states
    def state_count() @states.size end

    # Returns the number of edges
    def edge_count() @edges.size end

    #
    # Returns the i-th state of the state list.
    #
    # Raises:
    # - ArgumentError unless i is an Integer
    # - IndexError if i is not in [0..state_count)
    #
    def ith_state(i)
      raise(ArgumentError, "Integer expected, #{i} found.", caller)\
        unless Integer === i
      raise(ArgumentError, "Invalid state index #{i}", caller)\
        unless i>=0 and i<state_count
      @states[i]
    end

    #
    # Returns state associated with the supplied state name, throws an exception if no such state can be found.
    #
    def get_state(name)
      raise(ArgumentError, "String expected, #{name} found.", caller)\
        unless String === name
        result = states.find do |s|
          name == s[:name]
        end
      raise(ArgumentError, "State #{name} was not found", caller)\
        if result.nil?
      result
    end

    #
    # Returns the i-th states of the state list.
    #
    # Raises:
    # - ArgumentError unless all _i_ are integers
    # - IndexError unless all _i_ are in [0..state_count)
    #
    def ith_states(*i)
      i.collect{|j| ith_state(j)}
    end

    #
    # Returns the i-th edge of the edge list.
    #
    # Raises:
    # - ArgumentError unless i is an Integer
    # - IndexError if i is not in [0..state_count)
    #
    def ith_edge(i)
      raise(ArgumentError, "Integer expected, #{i} found.", caller)\
        unless Integer === i
      raise(ArgumentError, "Invalid edge index #{i}", caller)\
        unless i>=0 and i<edge_count
      @edges[i]
    end

    #
    # Returns the i-th edges of the edge list.
    #
    # Raises:
    # - ArgumentError unless all _i_ are integers
    # - IndexError unless all _i_ are in [0..edge_count)
    #
    def ith_edges(*i)
      i.collect{|j| ith_edge(j)}
    end

    #
    # Calls block for each state of the automaton state list. States are
    # enumerated in index order.
    #
    def each_state() @states.each {|s| yield s if block_given?} end

    #
    # Calls block for each edge of the automaton edge list. Edges are
    # enumerated in index order.
    #
    def each_edge() @edges.each {|e| yield e if block_given?} end

    #
    # Returns an array with incoming edges of _state_. Edges are sorted by symbols
    # if _sorted_ is set to true. If two incoming edges have same symbol, no
    # order is guaranteed between them. Returned array may be modified.
    #
    # If _state_ is an Integer, this method returns the incoming edges of the
    # state'th state in the state list.
    #
    # Raises:
    # - IndexError if state is an Integer and state<0 or state>=state_count.
    # - ArgumentError if _state_ is not a valid state for this automaton.
    #
    def in_edges(state, sorted=false) to_state(state).in_edges(sorted) end

    #
    # Returns an array with outgoing edges of _state_. Edges are sorted by symbols
    # if _sorted_ is set to true. If two incoming edges have same symbol, no
    # order is guaranteed between them. Returned array may be modified.
    #
    # If _state_ is an Integer, this method returns the outgoing edges of the
    # state'th state in the state list.
    #
    # Raises:
    # - IndexError if state is an Integer and state<0 or state>=state_count.
    # - ArgumentError if state is not a valid state (not a state or not from this
    #   automaton)
    #
    def out_edges(state, sorted=false) to_state(state).out_edges(sorted) end

    #
    # Returns an array with the different symbols appearing on incoming edges of
    # _state_. Returned array does not contain duplicates and may be modified;
    # it is sorted if _sorted_ is set to true.
    #
    # If _state_ is an Integer, this method returns the incoming symbols of the
    # state'th state in the state list.
    #
    # Raises:
    # - IndexError if state is an Integer and state<0 or state>=state_count.
    # - ArgumentError if _state_ is not a valid state for this automaton.
    #
    def in_symbols(state, sorted=false) to_state(state).in_symbols(sorted) end

    #
    # Returns an array with the different symbols appearing on outgoing edges of
    # _state_. Returned array does not contain duplicates and may be modified;
    # it is sorted if _sorted_ is set to true.
    #
    # If _state_ is an Integer, this method returns the outgoing symbols of the
    # state'th state in the state list.
    #
    # Raises:
    # - IndexError if state is an Integer and state<0 or state>=state_count.
    # - ArgumentError if state is not a valid state (not a state or not from this
    #   automaton)
    #
    def out_symbols(state, sorted=false) to_state(state).out_symbols(sorted) end

    #
    # Returns an array with adjacent states (along incoming and outgoing edges)
    # of _state_. Returned array does not contain duplicates; it may be modified.
    #
    # If _state_ is an Integer, this method returns the adjacent states of the
    # state'th state in the state list.
    #
    # Raises:
    # - IndexError if state is an Integer and state<0 or state>=state_count.
    # - ArgumentError if state is not a valid state (not a state or not from this
    #   automaton)
    #
    def adjacent_states(state) to_state(state).adjacent_states() end

    #
    # Returns an array with adjacent states (along incoming edges) of _state_.
    # Returned array does not contain duplicates; it may be modified.
    #
    # If _state_ is an Integer, this method returns the incoming adjacent states
    # of the state'th state in the state list.
    #
    # Raises:
    # - IndexError if state is an Integer and state<0 or state>=state_count.
    # - ArgumentError if state is not a valid state (not a state or not from this
    #   automaton)
    #
    def in_adjacent_states(state) to_state(state).in_adjacent_states() end

    #
    # Returns an array with adjacent states (along outgoing edges) of _state_.
    # Returned array does not contain duplicates; it may be modified.
    #
    # If _state_ is an Integer, this method returns the outgoing adjacent states
    # of the state'th state in the state list.
    #
    # Raises:
    # - IndexError if state is an Integer and state<0 or state>=state_count.
    # - ArgumentError if state is not a valid state (not a state or not from this
    #   automaton)
    #
    def out_adjacent_states(state) to_state(state).out_adjacent_states() end

    #
    # Collects all initial states of this Automaton and returns it. Returned array
    # does not contain duplicates and may be modified.
    #
    # This method is epsilon symbol aware (represented with nil) on
    # non-deterministic automata, meaning that it actually computes the set of
    # reachable states from an initial state through strings respecting the
    # <tt>eps*</tt> regular expression, where eps is the epsilon symbol.
    #
    def initial_states
      if @initials.nil? or @initials.empty?
        @initials = compute_initial_states
      end
      @initials
    end

    #
    # Returns the initial state of the automaton. This method is expected to used
    # on deterministic automata only. Unlike initial_states, it returns one State
    # instance instead of an Array.
    #
    # When used with a non deterministic automaton, it returns one of the states
    # tagged as initial. Which one is returned must be considered a non
    # deterministic choice. This method is not epsilon symbol aware.
    #
    def initial_state
      initial_states[0]
    end

    # Internal implementation of initial_states.
    def compute_initial_states()
      initials = @states.select {|s| s.initial?}
      initials.collect{|s| s.epsilon_closure}.flatten.uniq
    end

    ### public write section #####################################################
    public

    #
    # Adds a new state.
    #
    # Arguments:
    # - data: user-data to attach to the state (see Automaton documentation).
    #
    # Raises:
    # - ArgumentError if _data_ is not a valid state data.
    #
    def add_state(data={})
      data = to_valid_state_data(data)

      # create new state, add it to state-list
      state = State.new(self, state_count, data)
      @states <<  state

      # let the automaton know that something has changed
      state_changed(:state_added, state)

      # return created state
      state
    end
    alias :create_state :add_state

    #
    # Adds _n_ new states in the automaton. Created states are returned as an
    # ordered array (order of states according to their index in state list).
    #
    # _data_ is duplicated for each created state.
    #
    def add_n_states(n, data={})
      created = []
      n.times do |i|
        created << add_state(block_given? ? data.merge(yield(i)) : data.dup)
      end
      created
    end
    alias :create_n_states :add_n_states

    #
    # Adds a new edge, connecting _from_ and _to_ states of the automaton.
    #
    # Arguments:
    # - from: either a State or a valid state index (Integer).
    # - to: either a State or a valid state index (Integer).
    # - data: user data to attach to the created edge (see Automaton documentation).
    #
    # Raises:
    # - IndexError if _from_ is an Integer but not in [0..state_count)
    # - IndexError if _to_ is an Integer but not in [0..state_count)
    # - ArgumentError if _from_ is not a valid state for this automaton.
    # - ArgumentError if _to_ is not a valid state for this automaton.
    # - ArgumentError if _data_ is not a valid edge data.
    #
    def add_edge(from, to, data)
      from, to, data = to_state(from), to_state(to), to_valid_edge_data(data)

      # create edge, install it, add it to edge-list
      edge = Edge.new(self, edge_count, data, from, to)
      @edges << edge
      from.send(:add_outgoing_edge, edge)
      to.send(:add_incoming_edge, edge)

      # let automaton know that something has changed
      state_changed(:edge_added, edge)

      # return created edge
      edge
    end
    alias :create_edge :add_edge
    alias :connect :add_edge

    #
    # Adds all states and transitions (as copies) from a different automaton.
    # None of the added states are made initial. Returns the (associated state
    # of the) initial state of the added part.
    #
    # This method is deprecated and should not be used anymore. Use dup instead.
    #
    # In order to ensure that names of the new states do not clash with names of
    # existing states, state names may have to be removed from added states;
    # this is the case if _clear_names_ is set to true.
    #
    def add_automaton(fa, clear_names = true)
      initial = nil
      fa.dup(self){|source,target|
        initial = target if target.initial?
        target[:initial] = false
        target[:name] = nil if clear_names
      }
      initial
    end

    #
    # Constructs a replica of this automaton and returns a copy.
    #
    # This copy can be modified in whatever way without affecting the original
    # automaton.
    #
    def dup(fa = Automaton.new)
      added = states.collect do |source|
        target = fa.add_state(source.data.dup)
        yield(source, target) if block_given?
        target
      end
      edges.each do |edge|
        from, to = added[edge.from.index], added[edge.to.index]
        fa.connect(from, to, edge.data.dup)
      end
      fa
    end

    #
    # Drops a state of the automaton, as well as all connected edges to that state.
    # If _state_ is an integer, the state-th state of the state list is removed.
    # This method returns the automaton itself.
    #
    # Raises:
    # - IndexError if _edge_ is an Integer but not in [0..edge_count)
    # - ArgumentError if _edge_ is not a valid edge for this automaton.
    #
    def drop_state(state)
      state = to_state(state)
      # remove edges first: drop_edges ensures that edge list is coherent
      drop_edges(*(state.in_edges + state.out_edges).uniq)

      # remove state now and renumber
      @states.delete_at(state.index)
      state.index.upto(state_count-1) do |i|
        @states[i].send(:index=, i)
      end
      state.send(:index=, -1)

      state_changed(:state_dropped, state)
      self
    end
    alias :delete_state :drop_state

    #
    # Drops all states passed as parameter as well as all their connected edges.
    # Arguments may be state instances, as well as valid state indices. Duplicates
    # are even supported. This method has no effect on the automaton and raises
    # an error if some state argument is not valid.
    #
    # Raises:
    # - ArgumentError if one state in _states_ is not a valid state of this
    #   automaton.
    #
    def drop_states(*states)
      # check states first
      states = states.collect{|s| to_state(s)}.uniq.sort
      edges  = states.collect{|s| (s.in_edges + s.out_edges).uniq}.flatten.uniq.sort

      # Remove all edges, we do not use drop_edges to avoid spending too much
      # time reindexing edges. Moreover, we can do it that way because we take
      # edges in reverse indexing order (has been sorted previously)
      until edges.empty?
        edge = edges.pop
        edge.source.send(:drop_outgoing_edge,edge)
        edge.target.send(:drop_incoming_edge,edge)
        @edges.delete_at(edge.index)
        edge.send(:index=, -1)
        state_changed(:edge_dropped, edge)
      end

      # Remove all states, same kind of hack is used
      until states.empty?
        state = states.pop
        @states.delete_at(state.index)
        state.send(:index=, -1)
        state_changed(:state_dropped, state)
      end

      # sanitize state and edge lists
      @states.each_with_index {|s,i| s.send(:index=,i)}
      @edges.each_with_index {|e,i| e.send(:index=,i)}

      self
    end

    #
    # Drops an edge in the automaton. If _edge_ is an integer, the edge-th edge
    # of the edge list is removed. This method returns the automaton itself.
    #
    # Raises:
    # - IndexError if _edge_ is an Integer but not in [0..edge_count)
    # - ArgumentError if _edge_ is not a valid edge for this automaton.
    #
    def drop_edge(edge)
      edge = to_edge(edge)
      @edges.delete_at(edge.index)
      edge.from.send(:drop_outgoing_edge,edge)
      edge.to.send(:drop_incoming_edge,edge)
      edge.index.upto(edge_count-1) do |i|
        @edges[i].send(:index=, i)
      end
      edge.send(:index=,-1)
      state_changed(:edge_dropped, edge)
      self
    end
    alias :delete_edge :drop_edge

    #
    # Drops all edges passed as parameters. Arguments may be edge objects,
    # as well as valid edge indices. Duplicates are even supported. This method
    # has no effect on the automaton and raises an error if some edge argument
    # is not valid.
    #
    # Raises:
    # - ArgumentError if one edge in _edges_ is not a valid edge of this automaton.
    #
    def drop_edges(*edges)
      # check edges first
      edges = edges.collect{|e| to_edge(e)}.uniq

      # remove all edges
      edges.each do |e|
        @edges.delete(e)
        e.from.send(:drop_outgoing_edge,e)
        e.to.send(:drop_incoming_edge,e)
        e.send(:index=, -1)
        state_changed(:edge_dropped, e)
      end
      @edges.each_with_index do |e,i|
        e.send(:index=,i)
      end

      self
    end
    alias :delete_edges :drop_edges

    ### protected section ########################################################
    protected

    #
    # Converts a _state_ argument to a valid State of this automaton.
    # There are three ways to refer to a state, by position in the internal
    # collection of states, using an instance of State and using a name of a
    # state (represented with a String).
    #
    # Raises:
    # - IndexError if state is an Integer and state<0 or state>=state_count.
    # - ArgumentError if state is not a valid state (not a state or not from this
    #   automaton)
    #
    def to_state(state)
      case state
      when State
        return state if state.automaton==self and state==@states[state.index]
        raise ArgumentError, "Not a state of this automaton", caller
      when Integer
        return ith_state(state)
      when String
        result = get_state(state)
        return result unless result.nil?
      end
      raise ArgumentError, "Invalid state argument #{state}", caller
    end

    #
    # Converts an _edge_ argument to a valid Edge of this automaton.
    #
    # Raises:
    # - IndexError if _edge_ is an Integer but not in [0..edge_count)
    # - ArgumentError if _edge_ is not a valid edge (not a edge or not from this
    #   automaton)
    #
    def to_edge(edge)
      case edge
      when Edge
        return edge if edge.automaton==self and edge==@edges[edge.index]
        raise ArgumentError, "Not an edge of this automaton", caller
      when Integer
        return ith_edge(edge)
      end
      raise ArgumentError, "Invalid edge argument #{edge}", caller
    end

    #
    # Checks if a given user-data contains enough information to be attached to
    # a given state. Returns the data if ok.
    #
    # Raises:
    # - ArgumentError if data is not considered a valid state data.
    #
    def to_valid_state_data(data)
      raise(ArgumentError,
            "User data should be an Hash", caller) unless Hash===data
      data
    end

    #
    # Checks if a given user-data contains enough information to be attached to
    # a given edge. Returns the data if ok.
    #
    # Raises:
    # - ArgumentError if data is not considered a valid edge data.
    #
    def to_valid_edge_data(data)
      return {:symbol => data} if data.nil? or data.is_a?(String)
      raise(ArgumentError,
            "User data should be an Hash", caller) unless Hash===data
      raise(ArgumentError,
            "User data should contain a :symbol attribute.",
            caller) unless data.has_key?(:symbol)
      raise(ArgumentError,
            "Edge :symbol attribute cannot be an array.",
            caller) if Array===data[:symbol]
      data
    end

    ### public sections with useful utilities ####################################
    public

    # Returns true if the automaton is deterministic, false otherwise
    def deterministic?
      @deterministic = @states.all?{|s| s.deterministic?} if @deterministic.nil?
      @deterministic
    end

    ### public & protected sections about alphabet ###############################
    protected

    # Deduces the alphabet from the automaton edges.
    def deduce_alphabet
      edges.collect{|e| e.symbol}.uniq.compact.sort
    end

    public

    # Returns the alphabet of the automaton.
    def alphabet
      @alphabet || deduce_alphabet
    end

    # Sets the aphabet of the automaton. _alph_ is expected to be an array without
    # nil nor duplicated. This method raises an ArgumentError otherwise. Such an
    # error is also raised if a symbol used on the automaton edges is not included
    # in _alph_.
    def alphabet=(alph)
      raise ArgumentError, "Invalid alphabet" unless alph.uniq.compact.size==alph.size
      raise ArgumentError, "Invalid alphabet" unless deduce_alphabet.reject{|s| alph.include?(s)}.empty?
      @alphabet = alph.sort
    end

    ### public section about coercions ###########################################
    public

    # Returns a finite automaton
    def to_fa
      self
    end

    # Returns a deterministic finite automaton
    def to_dfa
      self.deterministic? ? self : self.determinize
    end

    # Returns a canonical deterministic finite automaton
    def to_cdfa
      cdfa = self
      cdfa = cdfa.determinize unless self.deterministic?
      cdfa = cdfa.complete    unless self.complete?
      cdfa = cdfa.minimize
      cdfa
    end

    # Returns a regular language
    def to_reglang
      RegLang.new(self)
    end

    ### public section about dot utilities #######################################
    protected

    #
    # Converts a hash of attributes (typically automaton, state or edge attributes)
    # to a <code>[...]</code> dot string. Braces are part of the output.
    #
    def attributes2dot(attrs)
      buffer = ""
      attrs.keys.sort{|k1,k2| k1.to_s <=> k2.to_s}.each do |key|
        buffer << " " unless buffer.empty?
        value = attrs[key].to_s.gsub('"','\"')
        buffer << "#{key}=\"#{value}\""
      end
      buffer
    end

    public

    #
    # Generates a dot output from an automaton. The rewriter block takes
    # two arguments: the first one is a Markable instance (graph, state or
    # edge), the second one indicates which kind of element is passed (through
    # :automaton, :state or :edge symbol). The rewriter is expected to return a
    # hash-like object providing dot attributes for the element.
    #
    # When no rewriter is provided, a default one is used by default, providing
    # the following behavior:
    # - on :automaton
    #
    #   {:rankdir => "LR"}
    #
    # - on :state
    #
    #   {:shape => "doublecircle/circle" (following accepting?),
    #    :style => "filled",
    #    :fillcolor => "green/red/white" (if initial?/error?/else, respectively)}
    #
    # - on edge
    #
    #   {:label => "#{edge.symbol}"}
    #
    def to_dot(sort_states = true, &rewriter)
      unless rewriter
        to_dot(sort_states) do |elm, kind|
          case kind
            when :automaton
              {:pack => true, :rankdir => "LR", :ranksep => 0, :margin => 0}
            when :state
              {:shape => (elm.accepting? ? "doublecircle" : "circle"),
               :style => "filled",
               :color => "black",
               :fillcolor => (elm.initial? ? "green" : (elm.error? ? "red" : "white")),
               :width => 0.6, :height => 0.6, :fixedsize => true
              }
            when :edge
              {:label => elm.symbol.nil? ? '' : elm.symbol.to_s,
               :arrowsize => 0.7}
          end
        end
      else
        buffer = "digraph G {\n"
        attrs = attributes2dot(rewriter.call(self, :automaton))
        buffer << "  graph [#{attrs}];\n"
        ss = if sort_states
          self.depth
          states.sort{|s1,s2| s1[:depth] <=> s2[:depth]}
        else
          self.states
        end
        ss.each do |s|
          s.remove_mark(:depth) if sort_states
          attrs = attributes2dot(rewriter.call(s, :state))
          buffer << "  #{s.index} [#{attrs}];\n"
        end
        edges.each do |e|
          attrs = attributes2dot(rewriter.call(e, :edge))
          buffer << "  #{e.source.index} -> #{e.target.index} [#{attrs}];\n"
        end
        buffer << "}\n"
      end
    end

    ### public section about adl utilities #######################################
    public

    # Prints this automaton in ADL format
    def to_adl(buffer = "")
      Stamina::ADL.print_automaton(self, buffer)
    end

    ### public section about reordering ##########################################
    public

    # Uses a comparator block to reorder the state list.
    def order_states(&block)
      raise ArgumentError, "A comparator block must be given" unless block_given?
      raise ArgumentError, "A comparator block of arity 2 must be given" unless block.arity==2
      @states.sort!(&block)
      @states.each_with_index{|s,i| s.send(:index=, i)}
      self
    end

    ### protected section about changes ##########################################
    protected

    #
    # Fires by write method when an automaton change occurs.
    #
    def state_changed(what, infos)
      @initials = nil
      @deterministic = nil
    end

    protected :compute_initial_states

    DUM = Automaton.new{ add_state(:initial => true, :accepting => false) }
    DEE = Automaton.new{ add_state(:initial => true, :accepting => true)  }
  end # class Automaton

end # module Stamina
require_relative 'automaton/walking'
require_relative 'automaton/complete'
require_relative 'automaton/complement'
require_relative 'automaton/strip'
require_relative 'automaton/equivalence'
require_relative 'automaton/determinize'
require_relative 'automaton/minimize'
require_relative 'automaton/metrics'
require_relative 'automaton/compose'
require_relative 'automaton/hide'