-module(slowdown).

-export([run/0]).

-define(PORT_FROM, 5005).
-define(PORT_TO, 8005).
-define(BACKLOG, 10000).

run() ->

    io:format("Slowdown 0.1~n"),
    {ok, Socket} = gen_tcp:listen(0, [
				      {backlog, ?BACKLOG}, {reuseaddr, true},
				      {port, ?PORT_FROM}, binary, {packet, 0}, {active, true}
				     ]),
    accept(Socket).

accept(Socket) ->
    {ok, ClientSocket} = gen_tcp:accept(Socket),
    Handler = spawn(fun() ->
			    receive
				go -> go
			    end,
			    {ok, TargetSocket} = 
				gen_tcp:connect("192.168.1.3", ?PORT_TO, [
									  binary, {nodelay, true}, {packet, 0}, {active, true}
									 ]),
			    loop(TargetSocket, ClientSocket)
		    end),
    gen_tcp:controlling_process(ClientSocket, Handler),
    Handler ! go,
    accept(Socket).

send_slow(ClientSocket, Data) ->
    gen_tcp:send(ClientSocket,[Data]),
    timer:sleep(7).

loop(TargetSocket, ClientSocket) ->
    
    Continue = receive
		   {tcp, TargetSocket, Data} ->
		       lists:foreach(fun(X) ->
					     send_slow(ClientSocket,X) end, binary:bin_to_list(Data)),
		       true;
		   {tcp, ClientSocket, Data} -> 
		       gen_tcp:send(TargetSocket, Data), 
		       true;
		   {tcp_closed, _} ->
		       gen_tcp:close(TargetSocket),
		       gen_tcp:close(ClientSocket),
		       false;
		   X ->
		       io:format("Unknown msg: ~p", [X]),
		       gen_tcp:close(TargetSocket),
		       gen_tcp:close(ClientSocket),
		       false
	       end,
    case Continue of
	true -> loop(TargetSocket, ClientSocket);
	false -> ok
    end.
