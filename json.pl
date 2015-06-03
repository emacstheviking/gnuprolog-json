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
%% Having said that, it does contain some useful code for parsing a
%% JSON string as described here: http://json.org, and can also
%% convert a Prolog term (suitably formatted) into a JSON string.
%%
%%
%% MAIN PREDICATES:
%%
%% json_decode(JSONString, Out).
%%        - all objects are wrapped in a functor: obj().
%%        - all strings are wrapped in a functor: str().
%%
%%
%% json_encode(Term, JSONString).
%%        - output from json_decode/2 is valid input.
%%        - throws exceptions if fed a diet of crap.
%%
%%
%% UTILITY FUNCTIONS:
%%
%% This file (json.pl) contains some bolt-on predicates that make life
%% a bit easier when dealing with a decoded JSON string. Contains may
%% vary, be buggy etc. All improvements, suggestions, optimisations
%% welcome via GitHub.
%%
%%====================================================================

:- include(json_decode).
:- include(json_encode).


%%--------------------------------------------------------------------
%% json_find/3
%%
%% Simple list search for a specific key in a list returned from
%% json_decode/2. NON-RECURSIVE search!
%%
%% Linear searching is of course inherently slow for things at the end
%% of the list. This is not expected to be an issue for small JSON
%% packets. And slow is relative anyway.
%%
%%--------------------------------------------------------------------
json_find(_, [], undefined) :- !.

json_find(K, [K-V | _], V) :- !.

json_find(K, [_ | T], V) :-
	json_find(K, T, V).


%%--------------------------------------------------------------------
%% json_find_str/3
%%
%% Finds a string called K in the list. Non-recursive. The returned
%% string is unwrapped from its functor as a convenience as we know
%% the type from the calling context.
%%--------------------------------------------------------------------
json_find_str(K, L, V) :-
	json_find(K, L, str(V)).


%%--------------------------------------------------------------------
%% json_find_obj/3
%%
%% Finds an object called K in the list. Non-recursive. The returned
%% object is unwrapped from its functor as a convenience.
%%--------------------------------------------------------------------
json_find_obj(K, L, V) :-
	json_find(K, L, obj(V)).


%%--------------------------------------------------------------------
%% list_keys/2
%%
%% Given a K-V pair list this will return a list of the keys. Useful
%% for trawling through unfamilair JSON data to see what there is.
%%--------------------------------------------------------------------
list_keys([],[]).
list_keys(L, Out) :- list_keys(L, [], Out).
list_keys([], Acc, Out) :- reverse(Acc, Out).
list_keys([K-_|T], Acc, Out) :- list_keys(T, [K|Acc], Out).




%%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%%
%% Work in progress... I am building a FastCGI Microservices kernel
%% using GNU Prolog and linear list searching etc is slow on large
%% lists so this predicate provides a simple balanced binary tree in
%% case I need it.
%%
%% TODO: predicate to convert json_decode/2 output into this structure
%% but not right now as I don't need it.
%%
%%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%%
%% AOP.p250.Binary tree dictionary
%%
%%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%%
%% dict/3
%%
%% Dictionary entry structure is: kv(Key, Value, Left, Right)
%%
%% First, populate a dictionary then on subsequent calls to lookup(),
%% test the ValOut variable to see if it instantiated to a value or
%% not. If not, then we didn't find a match.
%%
%% *** NOTE *** This predicate set works such that asking for a key
%% not already present will cause that key to be added! Therefore, be
%% very careful about passing around a stable dictionary and adding
%% things to it and then it going out of scope e.g. backtracking might
%% have some surprises but I am sure I will learn more and be amazed!
%%
%%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
dict(Key, kv(Key, Value, _Left, _Right), ValOut) :-
	!,
	Value = ValOut.

dict(Key, kv(Key1, _Value, Left, _Right), ValOut) :-
	Key @< Key1,
	dict(Key, Left, ValOut).

dict(Key, kv(Key1, _Value, _Left, Right), ValOut) :-
	Key @> Key1,
	dict(Key, Right, ValOut).
