-module(makeup_Saegesser).
-compile(export_all).
-author("Zach Saegesser").



start(FileString) ->
  LstNodes = readlines(FileString),
  Nodes = popDict(LstNodes, dict:new(), 1),
  updatesensors(Nodes, LstNodes),
  NIds = getIds(dict:to_list(Nodes), []),
  spawn(makeup, timer, [NIds]).

popDict([], Dict, _Count) ->
  Dict;
popDict([{Node, _Neighbors} | T], Dict, Count) ->
  NewDict = dict:store(Node, spawn(makeup, startsensor, [Count]), Dict),
  %io:fwrite("fetched = ~p\n", [dict:])
  popDict(T, NewDict, Count+1).

updatesensors(_Dict, []) ->
  io:fwrite("done updating\n");
updatesensors(Dict, [{Node, Neighbors} | T]) ->
  NeighIds = lists:map(fun(N) -> dict:fetch(N, Dict) end, Neighbors),
  ID = dict:fetch(Node, Dict),
  ID ! {update, NeighIds},
  updatesensors(Dict, T).



startsensor(Num) ->
  receive
    {update, Neighbors} ->
      %io:fwrite("Node ~w started with ~w neighbors \n", [Num, Neighbors]),
      sensor(Num, rand:uniform(100), Neighbors, 0, [])
  end.

sensor(Num, Val, Neighbors, Received, NeighborsVals) ->
  receive
    {directReading, NewVal} ->
      %io:fwrite("Node ~w recieved directReading\n", [Num]),
      sensor(Num, NewVal, Neighbors, Received, NeighborsVals);
    {tick} ->
      io:fwrite("Recieved tick -- Node ~w currently has value ~w\n", [Num, Val]),
      %io:fwrite("Node ~w recieved tick\n", [Num]),
      lists:foreach(fun(N) -> N ! {avg, Val} end, Neighbors),
      sensor(Num, Val, Neighbors, Received, NeighborsVals);
    {avg, NVal} ->
      %io:fwrite("Node: ~w Neighbors: ~w, ReceivedNum: ~w\n", [Num, Neighbors, Received]),
      ReceivedN = Received+1,
      LengthN = lists:flatlength(Neighbors),
      if
        ReceivedN == LengthN ->
          %io:fwrite("Node ~w sending ~w to avg\n", [Num, NeighborsVals ++ [NVal]]),
          sensor(Num, average(NeighborsVals++ [NVal]), Neighbors, 0, []);
        true ->
          sensor(Num, Val, Neighbors, Received+1, NeighborsVals ++ [NVal])
      end
    end.

timer(NPids) ->
  timer:sleep(1000),
  lists:foreach(fun(N) -> N ! {tick} end, NPids),
  timer(NPids).

getIds([], NIds) ->
  NIds;
getIds([{_Node, Id} | T], NIds) ->
  getIds(T, NIds ++ [Id]).


average(X) -> sum(X) / len(X).

sum([H|T]) -> H + sum(T);
sum([]) -> 0.

len([_|T]) -> 1 + len(T);
len([]) -> 0.

readlines ( FileName ) ->
  {ok , Device } = file : open ( FileName , [ read ]) ,
  try get_all_lines ( Device )
    after file : close ( Device )
  end.

get_all_lines ( Device ) ->
  case io : get_line ( Device , "") of
    eof -> [];
    Line -> Ss = string : tokens ( Line ," ,\n"),
    [{ hd ( Ss ), tl ( Ss )}] ++ get_all_lines ( Device )
  end.
