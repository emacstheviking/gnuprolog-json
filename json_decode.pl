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
%% This is a JSON decoder written to the BNF form shown on the right
%% hand side of this page:
%%
%%    http://json.org
%%
%% *I have made one exception* in that I am willing to *allow trailing
%% comma characters in object and list content* as that seems pretty
%% widespread out in the wild and I want this library to be robust and
%% useful to me at least.
%%
%%====================================================================


%%--------------------------------------------------------------------
%% json_decode/2
%%
%% We use phrase/3 to avoid failing because of trailing characters
%% after the final closing "}" character. For example, a LF character
%% left on a new line of its own.
%%--------------------------------------------------------------------
json_decode(String, JSON) :-
	list(String),
	phrase(json_object(JSON), String, _).

json_decode(Filename, JSON) :-
	open(Filename, read, F),
	json_loadfile(F, [], Buffer),
	phrase(json_object(JSON), Buffer, _),
	close(F).


%%--------------------------------------------------------------------
%% json_loadfile/3
%%
%% Loads the contents of a file (any file) into a character code list.
%%--------------------------------------------------------------------
json_loadfile(F, Acc, Out) :-
	at_end_of_stream(F),
	reverse(Acc, Out),
	!.

json_loadfile(F, Acc, Out) :-
	get_code(F, C),
	json_loadfile(F, [C|Acc], Out).


%%--------------------------------------------------------------------
%% json_object//1.
%%
%% This is the top-level JSON decoding entry point. Called with
%% phrase/2 it attempts to scan and translate an in-memory character
%% codes list assumed to be a valid JSON structure, and when done, if
%% successful, return a Prolog representation of that object.
%%
%% If the predicate fails, all you can say is that the JSON was
%% malformed according to the rules by which it operates, governed by
%% those at http://json.org
%%--------------------------------------------------------------------
json_object(JSON) -->
	json_skipws,
	(
	 "{", json_skipws, "}", {JSON = obj([])}
	;
	 "{", json_skipws,
	 json_members([], Content),
	 json_skipws, "}",
	 !,
	 {JSON = obj(Content)}
	).


%%--------------------------------------------------------------------
%% json_array//1.
%%
%% Extraction of a JSON array. We recognise the empty array, returned
%% as an empty list and a list of arbitrarily long comma separated
%% elements.
%%
%%--------------------------------------------------------------------
json_array(Elements) -->
	json_skipws,
	(
	 "[", json_skipws, "]", {Elements = []}
	;
	 "[", json_skipws, json_elements([], Elements), json_skipws, "]"
	).


%%--------------------------------------------------------------------
%% json_skipws//0.
%%
%% Skips optional whitespace. Depends on json_skipws1//1 to determine
%% what characters are deemed to be non-important to the JSON parsing.
%%--------------------------------------------------------------------
json_skipws -->
	json_skipws1, json_skipws, !
	;
	json_skipws1, !
	;
	[].


%%--------------------------------------------------------------------
%% json_skipws1//0.
%%
%% Whitespace: simple but effective; anything not ASCII printable is
%% considered to be whitespace for the purposes of JSON decoding.
%%--------------------------------------------------------------------
json_skipws1 --> [C], { C=<32 ; C>=127}.


%%--------------------------------------------------------------------
%% json_elements//2.
%%
%% Extraction of a comma separated list of elements.
%%
%% Being realistic about what json.org says, we will allow a trailing
%% comma after the final element as machine generated code and sloppy
%% human code exhibits that trait in the real world very very
%% frequently.
%%--------------------------------------------------------------------
json_elements(Acc, Elements) -->
	json_skipws,
	(
	 json_value(V), json_skipws, ",", json_skipws,
	 !,
	 json_elements([V | Acc], Elements)
	)
	;
	(
	 (
	  json_value(V)
	  ->
	   {
	    All = [V | Acc],
	    reverse(All, Elements)
	   }
	 ;
	  %% Dangling comma, take what we have.
	  {reverse(Acc, Elements)}
	 )
	).


%%--------------------------------------------------------------------
%% json_members//2.
%%
%% Extraction of "members" of an object. A member is a sequence of one
%% or more comma separated "pairs". The order of extraction is
%% maintained in case it is important at a higher application level.
%%--------------------------------------------------------------------
json_members(Acc, Members) -->
	json_skipws,
	(
	 json_pair(P), json_skipws, ",", json_skipws,
	 !,
	 json_members([P | Acc], Members)
	)
	;
	(
	 (
	  json_pair(P)
	 ->
	  {
	   All = [P | Acc],
	   reverse(All, Members)
	  }
	 ;
	  {reverse(Acc, Members)}
	 )
	).


%%--------------------------------------------------------------------
%% json_value//1.
%%
%% Extraction of high-level objects for structure building. The cut is
%% to commit to the parsed term. Take it out, watch it go slower. Much
%% slower! Like, an order of magnitude slower. I think this is the
%% first time I appreciate what a well placed cut can actually do in
%% terms of performance.
%%--------------------------------------------------------------------
json_value(V) -->
	json_skipws,
	(
	 json_string(V), !
	;
	 json_number(V), !
	;
	 "true",  {V = true}, !
	;
	 "false", {V = false}, !
	;
	 "null",  {V = null}, !
	;
	 json_object(V), !
	;
	 json_array(V), !
	).


%%--------------------------------------------------------------------
%% json_pair//2.
%%
%% Extraction of K-V term for object definitions. Until the issue of
%% atom starvation arises the keys are returned as atom values.
%%--------------------------------------------------------------------
json_pair(K-V) -->
	json_skipws,
	json_string(str(KCodes)),
	{atom_codes(K, KCodes)},
	json_skipws,
	":",
	json_skipws,
	!,
	json_value(V).


%%--------------------------------------------------------------------
%% json_string//1.
%%
%% Extraction of characters into a string. We return the string as a
%% character codes list. Empty string will of course be [].
%%--------------------------------------------------------------------
json_string(Str) -->
	(
	 [34], [34], {Str = str([])}, !
	)
	;
	(
	 [34], json_strget([], Tmp), [34], !,
	 {Str = str(Tmp)}
	).


%%--------------------------------------------------------------------
%% json_strget//2
%%
%% Extraction of a single character. We have three predicates, the
%% first manages the sequence (backslash, double-quote), the second
%% manages generic characters and the final predicate is when we have
%% consumed the contents of the string and need to reverse the
%% accumulator for presentation.
%%--------------------------------------------------------------------
json_strget(Acc, Out) -->
	[92, Chr],
	json_strget([Chr, 92 | Acc], Out).

json_strget(Acc, Out) -->
	json_char(Chr),
	json_strget([Chr | Acc], Out).

json_strget(Acc, Str) --> [],
	{reverse(Acc, Str)}, !.


%%--------------------------------------------------------------------
%% json_char//1.
%%
%% Within the context of our DCG ruleset, we allow any thing into a
%% string except the double quote character. The only exception we
%% recognise is the sequence '\"' used to escape a double quote within
%% the string. The json_strget//2 predicate handles that situation.
%% anything BUT a double-quote character is a valid character
%%--------------------------------------------------------------------
json_char(C) --> [C], {C \= 34}.


%%--------------------------------------------------------------------
%% jon_number//1.
%%
%% Extraction of numbers from the source. A number can be a straight
%% integer, a decimal or a floating point representation. All are
%% returned as strings to prevent internal rounding and to preserve
%% the transmitted value.
%%--------------------------------------------------------------------
json_number(Number) -->
	json_skipws,
	json_int(N), json_frac(F), json_exp(E, Exp),
	{json_make_number("~d.~d~s~d", [N, F, E, Exp], Number)}, !.

json_number(Number) -->
	json_skipws,
	json_int(N), json_frac(F),
	{json_make_number("~d.~d",[N, F], Number)}, !.

json_number(Number) -->
	json_skipws,
	json_int(N), json_exp(E, Exp),
	{json_make_number("~d.~s~d",[N, E, Exp], Number)}, !.

json_number(Number) -->
	json_skipws, json_int(Number), !.


%%--------------------------------------------------------------------
%% json_make_number/3.
%%
%% As JSON does NOT have decent number handling, and to avoid any
%% transport issues, any "real" numbers are converted into strings
%% internally. It will be the consumers responsibility to convert its
%% type if required.
%%--------------------------------------------------------------------
json_make_number(Fmt, Args, Number) :-
	format_to_codes(Buf, Fmt, Args),
	Number = n(Buf).


%%--------------------------------------------------------------------
%% json_int//1
%%
%% Extraction of integers only, positive and negative.
%%--------------------------------------------------------------------
json_int(Val) -->
	( %% positive digit, >  0
	 json_digit19(D1),
	 json_digsum(D1, Val), !
	)
	;
	( %% negative multiple digits
	 "-",
	 json_digit19(D1),
	 json_digsum(D1, Total),
	 {Val is -Total}, !
	)
	;
	( %% negative single digit
	 "-",
	 json_digit(D1),
	 {Val is -D1};
	 json_digit(Val), !
	).

%%--------------------------------------------------------------------
%% json_frac//1.
%% json_exp//2.
%%
%% Extraction of fractional part and exponent for floating point
%% numbers.
%%--------------------------------------------------------------------
json_frac(Frac)  --> ".", json_digits(Frac).
json_exp(E, Exp) --> json_e(E), json_digits(Exp).


%%--------------------------------------------------------------------
%% json_e//1.
%%
%% Consume an exponent introducer for positive and negative values.
%%--------------------------------------------------------------------
json_e("E+") --> "e+", !.
json_e("E+") --> "E+", !.
json_e("E-") --> "e-", !.
json_e("E-") --> "E-", !.
json_e("E+") --> "e",  !.
json_e("E+") --> "E",  !.


%%--------------------------------------------------------------------
%% json_digit//1.
%%
%% Scan a single digit 0-9 or 1-9
%%--------------------------------------------------------------------
json_digit(D) --> [Chr], { "0"=<Chr, Chr=<"9", D is Chr-"0"}.
json_digit19(D) --> json_digit(D), {D > 0}.


%%--------------------------------------------------------------------
%% json_digits//1.
%% Scan a a series of digits, returns actual value
%%--------------------------------------------------------------------
json_digits(Val) --> json_digit(D0), json_digsum(D0, Val).
json_digits(Val) --> json_digit(Val).


%%--------------------------------------------------------------------
%% json_digsum//2.
%%
%% Scan/consume digits returning decimal value to json_digits//1.
%%--------------------------------------------------------------------
json_digsum(Acc, N) -->
	json_digit(D),
	{Acc1 is Acc*10 + D},
	json_digsum(Acc1, N).

json_digsum(N, N) --> [], !.
