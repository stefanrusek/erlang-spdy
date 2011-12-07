%%
%% One of these is spawned per stream (SYN_STREAM)
%%
%% It delegates to the (currently hardcoded) callback module, which will
%% makes the request look like a normal http req to the app
%% 
-module(espdy_stream).
-behaviour(gen_server).

-include("include/espdy.hrl").

-compile(export_all).

%% API
-export([start_link/6, send_data_fin/1, send_data/2, closed/2, received_data/2,
         send_response/3
        ]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
     terminate/2, code_change/3]).

-record(state, {streamid, pid, mod, mod_state, headers, z_headers, spdy_opts}).

%% API
start_link(StreamID, Pid, Headers, Mod, Zcontext, Opts) ->
    gen_server:start(?MODULE, [StreamID, Pid, Headers, Mod, Zcontext, Opts], []).

send_data(Pid, Data) when is_pid(Pid), is_binary(Data) ->
    gen_server:cast(Pid, {data, Data}).

send_data_fin(Pid) when is_pid(Pid) ->
    gen_server:cast(Pid, {data, fin}).

closed(Pid, Reason) when is_pid(Pid) ->
    gen_server:cast(Pid, {closed, Reason}).

received_data(Pid, Data) ->
    gen_server:cast(Pid, {received_data, Data}).

send_response(Pid, Headers, Body) ->
    gen_server:cast(Pid, {send_response, Headers, Body}).


%% gen_server callbacks

init([StreamID, Pid, Headers, Mod, __Z, Opts]) ->
    self() ! init_callback,
    Z = zlib:open(),
    ok = zlib:deflateInit(Z),
    %%ok = zlib:deflateInit(Z, best_compression,deflated, 15, 9, default),
    zlib:deflateSetDictionary(Z, ?HEADERS_ZLIB_DICT),
    {ok, #state{streamid=StreamID, pid=Pid, mod=Mod, headers=Headers, z_headers=Z, spdy_opts=Opts}}.

handle_call(_Request, _From, State) ->
    Reply = ok,
    {reply, Reply, State}.

handle_cast({received_data, Data}, State) ->
    {ok, NewModState} = (State#state.mod):handle_data(Data, State#state.mod_state),
    {noreply, State#state{mod_state=NewModState}};

handle_cast({headers_updated, Delta, NewMergedHeaders}, State) ->
    {ok, NewModState} = (State#state.mod):headers_updated(Delta, NewMergedHeaders, State#state.mod_state),
    {noreply, State#state{mod_state=NewModState}};

handle_cast({closed, Reason}, State) ->
    (State#state.mod):closed(Reason, State#state.mod_state),
    {stop, normal, State};

%% part of streamed body
handle_cast({data, Bin, false}, State) when is_binary(Bin) ->
    F = #dframe{streamid = State#state.streamid,
                flags=0,
                length=size(Bin),
                data=Bin},
    espdy_session:snd(State#state.pid, State#state.streamid, F),
    {noreply, State};

%% last of streamed body
handle_cast({data, Bin, true}, State) when is_binary(Bin) ->
    F = #dframe{streamid = State#state.streamid,
                flags=?DATA_FLAG_FIN,
                length=size(Bin),
                data=Bin},
    espdy_session:snd(State#state.pid, State#state.streamid, F),
    {stop, normal, State};

handle_cast({send_response, Headers, Body}, State) ->
    send_http_response(Headers, Body, State),
    %% stream is closed after replying
    {stop, normal, State}.
    

handle_info(init_callback, State) ->
    case (State#state.mod):init(self(), State#state.headers, State#state.spdy_opts) of
        %% In this case, the callback module provides the full response
        %% with no need for this process to persist for streaming the body
        %% so we can terminate this process after replying.
        {ok, Headers, Body} when is_list(Headers), is_binary(Body) ->
            send_http_response(Headers, Body, State),
            {stop, normal, State};
        %% The callback module will call msg us the send_http_response
        %% (typically from within the guts of cowboy_http_req, so that
        %%  we can reuse the existing http API)
        {ok, noreply} ->
            %% TODO track state, set timeout on getting the response from CB
            {noreply, State};
        %% CB module is going to stream us the body data, so we keep this process
        %% alive until we get the fin packet as part of the stream.
   %%%% {ok, Headers, stream, ModState} when is_list(Headers) ->
   %%%%     NVPairsData = encode_name_value_pairs(Headers, State#state.z_headers),
   %%%%     StreamID = State#state.streamid,
   %%%%     F = #cframe{type=?SYN_REPLY,
   %%%%                 flags=0, 
   %%%%                 length = 6 + byte_size(NVPairsData),
   %%%%                 data= <<0:1, 
   %%%%                         StreamID:31/big-unsigned-integer, 
   %%%%                         0:16/big-unsigned-integer, %% UNUSED
   %%%%                         NVPairsData/binary
   %%%%                       >>},
   %%%%     espdy_session:snd(State#state.pid, StreamID, F),
   %%%%     {noreply, State#state{mod_state=ModState}};
        %% CB module can't respond, because request is invalid
        {error, not_http} ->
            StreamID = State#state.streamid,
            F = #cframe{type=?RST_STREAM,
                        length=8,
                        data = <<0:1, 
                                 StreamID:31/big-unsigned-integer, 
                                 ?PROTOCOL_ERROR:32/big-unsigned-integer>>},
            espdy_session:snd(State#state.pid, StreamID, F),
            {stop, normal, State}
    end.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%% Internal functions

send_http_response(Headers, Body, State = #state{}) when is_list(Headers), is_binary(Body) ->
    io:format("Respond with: ~p ~p\n",[Headers, Body]),
    NVPairsData = encode_name_value_pairs(Headers, State#state.z_headers),
    StreamID = State#state.streamid,
    F = #cframe{type=?SYN_REPLY,
                flags=0, 
                length = 6 + byte_size(NVPairsData),
                data= <<0:1, 
                        StreamID:31/big-unsigned-integer, 
                        0:16/big-unsigned-integer, %% UNUSED
                        NVPairsData/binary>>
                    },
    espdy_session:snd(State#state.pid, StreamID, F),
    %% Send body response in exactly one data frame, with fin set.
    %% TODO fragment this if we hit some maximum frame size?
    F2 = #dframe{streamid=StreamID, 
                 flags=?DATA_FLAG_FIN,
                 length=size(Body),
                 data=Body},
    espdy_session:snd(State#state.pid, StreamID, F2),
    ok.

%% Encode the name/value compressed header block
encode_name_value_pairs(Headers, Z) when is_list(Headers) ->
    Num = length(Headers),
    L = lists:foldl(fun({K,V}, Acc) ->
        Klen = size(K),
        Vlen = size(V),
        [ <<Klen:16/unsigned-big-integer, K/binary, Vlen:16/unsigned-big-integer, V/binary>> | Acc ]
    end, [<< Num:16/unsigned-big-integer >>], Headers),
    ToDeflate = iolist_to_binary(lists:reverse(L)),
    %%io:format("TO DEFLATE: ~p\n",[ToDeflate]),
    Deflated = iolist_to_binary([ 
            zlib:deflate(Z, ToDeflate, full)
        ]),
    %%io:format("deflated: ~p\n",[Deflated]),
    zlib:close(Z),
    Deflated.