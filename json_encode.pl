%%====================================================================
%%
%% GNU Prolog -- JSON Library
%%
%% @author Sean James Charles <sean at objitsu dot com>
%%
%% I cannot guarantee this won't smoke your system. Use at your own
%% risk as usual, I take no responsibility for any damage you may
%% cause with it. Usual rules apply concerning this sort of thing.
%%
%%
%% This encodes a prolog structure into a JSON string. The structure
%% MUST follow certain rules to allow for the mismatch of JSON and
%% Prolog types i.e. a list of numbers could be a string so we need to
%% use functors to wrap strings and also to wrap objects to.
%%
%% If you follow the rules then you should have no real problems, they
%% are simple and are as follows:
%% 
%% RULES:
%%
%%   - atoms are converted to "atom" i.e. a string, enclosed in double
%%     quotes. No fancy escaping of the content is performed.
%%
%%   - to produce a string from a character code list you MUST enclose
%%     the string in the functor `str()` or it will be interpreted
%%     literally as a list of numbers. Only character codes are valid.
%%
%%   - to create an object "{}" with keys and values, you MUST use the
%%     functor `obj([])` and the list MUST contain key-value pairs using
%%     the '-' functor as is the normal case when using pairs.
%%
%%   - string contents are opaque. What you put in the str() functor
%%     is passed through with no processing. This means that putting
%%     "\n" in the string works as expected as GNU Prolog will have
%%     already converted that character for you. Try it.
%%
%%
%% EXAMPLES:
%%
%%    json_encode(obj([]),X).
%%        X = "{}".
%%
%%    json_encode(obj([app-str("GNU Prolog")]),X).
%%        X = {"app":"GNU Prolog"}
%%
%%    json_encode(obj([w1-str("Hello"), w1-str("World")]),X).
%%        X = {"w1":"Hello","w1":"World"}
%%
%% and finally (broken up for clarity I hope), just to show nested
%% objects in action:
%%
%%    json_encode(
%%      obj(
%%        [ status-42
%%        , keys-obj(
%%            [ k1-1
%%            , k2-obj([z-obj([age-49])])
%%            ]
%%          )
%%        ]
%%      ),
%%      X).
%%
%%    X = {"status":42,"keys":{"k1":1,"k2":{"z":{"age":49}}}}
%%
%%
%% All suggestions for more Prolog like code idioms, efficiency and
%% general all round improvements always welcome via GitHub as usual.
%%
%%====================================================================

:- include(mygputils).


%%--------------------------------------------------------------------
%% json_encode/2
%%
%% This will take a suitably formatted compound term and create a
%% character code list (string) that is hopefully acceptable JSON
%% content.
%%
%% This predicate MUST be able to consume the output from
%% json_decode/2 and produce the same structure, albeit not in the
%% same field order. FIELD ORDER IS IRRELEVANT in JSON and we make no
%% effort to preserve it.
%%
%%--------------------------------------------------------------------
%% json_encode(obj(X))/2 ENFORCES the top level {} requirement
%%--------------------------------------------------------------------
json_encode(obj([]), "{}").

json_encode(obj(Body), Out) :-
	fmap(json_kv_encode, Body, Terms),
	fmap(json_kv_stringify, Terms, Terms2),
	join(Terms2, 44, Terms3),
	flatten([0'{, Terms3, 0'}], Out).

json_encode(X, _) :-
	json_bad_object_error(X).


%%--------------------------------------------------------------------
%% json_encode/3 -- Accumulator predicates for json/2
%%--------------------------------------------------------------------
json_encode([obj(J) | T], Acc, Out) :-
	json_encode(J, [], Object1),
	flatten([123, Object1, 125], Object2),
	json_encode(T, [Object2|Acc], Out).

json_encode([H|T], Acc, Out) :-
	json_encode_term(H, Term),
	json_encode(T, [Term | Acc], Out).

json_encode([], Acc, Out) :-
	reverse(Acc, Out1),
	join(Out1, 44, Out2),
	flatten(Out2, Out).


%%--------------------------------------------------------------------
%% json_kv_encode/2
%%
%% Having previosuly establish the [K-V]-ness of the obj() content
%% these predicates are used to encode each term into a character code
%% list for the final JSON output.
%%
%% NOTE: that the special list head `K-obj(V)` is passed to the
%% predicate `json_encode/2` all over again as JSON is recursive in
%% nature.
%%--------------------------------------------------------------------
json_kv_encode(K-obj(V), K-Term) :-
	atom(K),
	json_encode(obj(V), Term).

json_kv_encode(K-V, K-Term) :-
	atom(K),
	json_encode_term(V, Term).

json_kv_encode([X|_], _, _):-
	json_bad_object_error(X).

json_bad_object_error(X) :-
	throw(error(json_kv_encode('obj(X), X MUST be [atom-term]. Given:',X))).


%%--------------------------------------------------------------------
%% json_kv_stringify/2
%%
%% Given a K-V pair, the key (assumed to be an atom at this stage) is
%% converted into a character code list and then Out is unified with
%% the JSON pair string "K":V
%%--------------------------------------------------------------------
json_kv_stringify(K-V, Out) :-
	atom(K),
	atom_codes(K, Key),
	flatten(V, Value),
	flatten([0'", Key, 0'", 0':, Value], Out). %"

json_kv_stringify(K-_, _) :-
	throw(error(json_kv_stringify('K MUST be atom, given: ', K))).


%%--------------------------------------------------------------------
%% json_encode_term/2
%%
%% This will attempt to convert a term into a character code list so
%% it canbe incorporated into the final JSON string.
%%
%% Failure to supply a recognised type or supported functor will cause
%% an exception to be thrown.
%%
%% @see json_decode for supported functors. [ str(), obj()]
%%--------------------------------------------------------------------
json_encode_term(obj(X), Out) :-
	json_encode(X, Tmp),
	Out = [0'{, Tmp, 0'}].


%% STRING -- str(X)
%%
%% Explicit string, wrap in double quotes
%% TODO: Escape content, caller must ensure this for now.
json_encode_term(str(T), String) :-
	fmap(json_escape_chr, T, Escaped),
	flatten([34, Escaped, 34], String).


%% NUMBER -- as-is
%%
%% Numbers are unboxed as it is pointless and inefficient.
json_encode_term(X, Out) :-
	number(X),
	number_codes(X, Out).


%% ATOM -- str(X)!
%%
%% An atom is converted into a string (should REUSE string handling)
%% TODO: Should either wrap into str() or call same string expander.
%% The empty list atom [] is treated as a special case.
json_encode_term([], "[]").
json_encode_term(X, Out) :-
	atom(X),
	atom_codes(X, Str),
	json_encode_term(str(Str), Out).


%% LIST -- []!
%%
%% A Prolog list is taken to be an actual list of stuff. Strings are
%% lists of characters hence the need for the str() functor in the
%% source data.
json_encode_term(X, Out) :-
	list(X),
	json_encode(X, [], List),
	Out = [ 0'[, List, 0'] ].


%% OOPS! We can't handle it, tell somebody...
json_encode_term(X, _) :-
	throw(error(json_encode_term(badtype, X))).


%%--------------------------------------------------------------------
%% json_escape_chr/2
%%
%% This is where we map special charcacters into JSON approved escape
%% sequence. \uNNNN is NOT currently handled.
%%--------------------------------------------------------------------
json_escape_chr(34, [0'\\, 0'"]).  %% \"  %editor fix!"
json_escape_chr(92, [0'\\, 0'\\]). %% \\
json_escape_chr(34, [0'\\, 0'/]).  %% \/
json_escape_chr(8,  [0'\\, 0'b]).  %% \b
json_escape_chr(12, [0'\\, 0'f]).  %% \f
json_escape_chr(10, [0'\\, 0'n]).  %% \n
json_escape_chr(13, [0'\\, 0'r]).  %% \r
json_escape_chr(9 , [0'\\, 0't]).  %% \t
json_escape_chr(C, C).

