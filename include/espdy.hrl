-define(LOG(S,A), io:format(case whereis(spdy_logging) of undefined -> standard_io; LoggingPid -> LoggingPid end, "~p\t" ++ S ++"\n",[self()|A])).

%% DATA FRAMES:
-record(spdy_data, {
    streamid :: integer(),
    flags = 0 :: integer(),
    data :: binary()
}).

%% CONTROL FRAMES:
-record(spdy_syn_stream, {
    version = 2 :: integer(),
    flags = 0   :: integer(),
    streamid    :: integer(),
    associd     :: integer(),
    priority    :: integer(),
    slot        :: integer(),
    headers     :: list()
}).
-record(spdy_syn_reply, {
    version = 2 :: integer(),
    flags = 0   :: integer(),
    streamid    :: integer(),
    headers     :: list()
}).
-record(spdy_rst_stream, {
    version = 2 :: integer(),
    flags = 0   :: integer(),
    streamid    :: integer(),
    statuscode  :: integer()
}).
-record(spdy_settings, {
    version = 2 :: integer(),
    flags = 0   :: integer(),
    settings    :: list()
}).
-record(spdy_setting_pair, {
    flags = 0   :: integer(),
    id          :: integer(),
    value       :: integer()
}).
-record(spdy_noop, {
    version = 2 :: integer()
}).
-record(spdy_ping, {
    version = 2 :: integer(),
    id          :: integer()
}).
-record(spdy_goaway, {
    version = 2 :: integer(),
    lastgoodid  :: integer(),
    statuscode  :: integer()
}).
-record(spdy_headers, {
    version = 2 :: integer(),
    flags = 0   :: integer(),
    streamid    :: integer(),
    headers     :: list()
}).
-record(spdy_window_update, {
    version = 3 :: integer(),
    streamid    :: integer(),
    delta_size  :: integer()
}).

%% STREAMS
-record(stream, {
    id :: integer(), %% If the server is initiating the stream, the Stream-ID must be even.
                     %% If the client is initiating the stream, the Stream-ID must be odd.
                     %% 0 is not a valid Stream-ID.
    pid,
    associd = 0 :: integer(),
    headers = [] :: list(), %% Streams optionally carry a set of name/value header pairs.
%%    clientclosed = false, %% them
%%    serverclosed = false, %% us
    priority :: integer(), %% The creator of a stream assigns a priority for that stream.
                           %% Priority is represented as an integer from 0 to 7.
                           %% 0 represents the highest priority and 7 represents the lowest priority.
    syn_replied = false :: boolean(), %% true once syn_reply was seen/sent
    window = 64*1024 :: integer() %% default transmit window size is 64KB
}).

%% CONSTANTS
-define(SYN_STREAM, 1).
-define(SYN_REPLY, 2).
-define(RST_STREAM, 3).
-define(SETTINGS, 4).
-define(NOOP, 5).
-define(PING, 6).
-define(GOAWAY, 7).
-define(HEADERS, 8).
-define(WINDOW_UPDATE, 9).
-define(CONTROL_FLAG_NONE, 0).
-define(CONTROL_FLAG_FIN, 1).
-define(CONTROL_FLAG_UNIDIRECTIONAL, 2).
-define(DATA_FLAG_NONE, 0).
-define(DATA_FLAG_FIN, 1).
-define(DATA_FLAG_COMPRESSED, 2).
-define(PROTOCOL_ERROR, 1).
-define(INVALID_STREAM, 1).
-define(REFUSED_STREAM, 2).
-define(UNSUPPORTED_VERSION, 4).
-define(CANCEL, 5).
-define(INTERNAL_ERROR, 6).
-define(FLOW_CONTROL_ERROR, 7).
-define(STREAM_IN_USE, 8).
-define(STREAM_ALREADY_CLOSED, 9).
-define(INVALID_CREDENTIALS, 10).
-define(FRAME_TOO_LARGE, 11).
-define(SETTINGS_UPLOAD_BANDWIDTH, 1).
-define(SETTINGS_DOWNLOAD_BANDWIDTH, 2).
-define(SETTINGS_ROUND_TRIP_TIME, 3).
-define(SETTINGS_MAX_CONCURRENT_STREAMS, 4).
-define(SETTINGS_CURRENT_CWND, 5).
-define(SETTINGS_DOWNLOAD_RETRANS_RATE, 6).
-define(SETTINGS_INITIAL_WINDOW_SIZE, 7).
-define(SETTINGS_CLIENT_CERTIFICATE_VECTOR_SIZE, 8).
-define(SETTINGS_FLAG_PERSIST_VALUE, 1).
-define(SETTINGS_FLAG_PERSISTED, 2).
-define(SETTINGS_FLAG_CLEAR_PREVIOUSLY_PERSISTED_SETTINGS, 1).

%% The entire contents of the name/value header block is compressed using zlib deflate.
%% There is a single zlib stream (context) for all name value pairs in one direction on a connection
-define(HEADERS_ZLIB_DICT, <<"optionsgetheadpostputdeletetraceacceptaccept-charsetaccept-encodingaccept-languageauthorizationexpectfromhostif-modified-sinceif-matchif-none-matchif-rangeif-unmodifiedsincemax-forwardsproxy-authorizationrangerefererteuser-agent100101200201202203204205206300301302303304305306307400401402403404405406407408409410411412413414415416417500501502503504505accept-rangesageetaglocationproxy-authenticatepublicretry-afterservervarywarningwww-authenticateallowcontent-basecontent-encodingcache-controlconnectiondatetrailertransfer-encodingupgradeviawarningcontent-languagecontent-lengthcontent-locationcontent-md5content-rangecontent-typeetagexpireslast-modifiedset-cookieMondayTuesdayWednesdayThursdayFridaySaturdaySundayJanFebMarAprMayJunJulAugSepOctNovDecchunkedtext/htmlimage/pngimage/jpgimage/gifapplication/xmlapplication/xhtmltext/plainpublicmax-agecharset=iso-8859-1utf-8gzipdeflateHTTP/1.1statusversionurl",0>>).

-define(HEADERS_ZLIB_DICT_V3, <<
    16#00, 16#00, 16#00, 16#07, 16#6f, 16#70, 16#74, 16#69,   % - - - - o p t i
    16#6f, 16#6e, 16#73, 16#00, 16#00, 16#00, 16#04, 16#68,   % o n s - - - - h
    16#65, 16#61, 16#64, 16#00, 16#00, 16#00, 16#04, 16#70,   % e a d - - - - p
    16#6f, 16#73, 16#74, 16#00, 16#00, 16#00, 16#03, 16#70,   % o s t - - - - p
    16#75, 16#74, 16#00, 16#00, 16#00, 16#06, 16#64, 16#65,   % u t - - - - d e
    16#6c, 16#65, 16#74, 16#65, 16#00, 16#00, 16#00, 16#05,   % l e t e - - - -
    16#74, 16#72, 16#61, 16#63, 16#65, 16#00, 16#00, 16#00,   % t r a c e - - -
    16#06, 16#61, 16#63, 16#63, 16#65, 16#70, 16#74, 16#00,   % - a c c e p t -
    16#00, 16#00, 16#0e, 16#61, 16#63, 16#63, 16#65, 16#70,   % - - - a c c e p
    16#74, 16#2d, 16#63, 16#68, 16#61, 16#72, 16#73, 16#65,   % t - c h a r s e
    16#74, 16#00, 16#00, 16#00, 16#0f, 16#61, 16#63, 16#63,   % t - - - - a c c
    16#65, 16#70, 16#74, 16#2d, 16#65, 16#6e, 16#63, 16#6f,   % e p t - e n c o
    16#64, 16#69, 16#6e, 16#67, 16#00, 16#00, 16#00, 16#0f,   % d i n g - - - -
    16#61, 16#63, 16#63, 16#65, 16#70, 16#74, 16#2d, 16#6c,   % a c c e p t - l
    16#61, 16#6e, 16#67, 16#75, 16#61, 16#67, 16#65, 16#00,   % a n g u a g e -
    16#00, 16#00, 16#0d, 16#61, 16#63, 16#63, 16#65, 16#70,   % - - - a c c e p
    16#74, 16#2d, 16#72, 16#61, 16#6e, 16#67, 16#65, 16#73,   % t - r a n g e s
    16#00, 16#00, 16#00, 16#03, 16#61, 16#67, 16#65, 16#00,   % - - - - a g e -
    16#00, 16#00, 16#05, 16#61, 16#6c, 16#6c, 16#6f, 16#77,   % - - - a l l o w
    16#00, 16#00, 16#00, 16#0d, 16#61, 16#75, 16#74, 16#68,   % - - - - a u t h
    16#6f, 16#72, 16#69, 16#7a, 16#61, 16#74, 16#69, 16#6f,   % o r i z a t i o
    16#6e, 16#00, 16#00, 16#00, 16#0d, 16#63, 16#61, 16#63,   % n - - - - c a c
    16#68, 16#65, 16#2d, 16#63, 16#6f, 16#6e, 16#74, 16#72,   % h e - c o n t r
    16#6f, 16#6c, 16#00, 16#00, 16#00, 16#0a, 16#63, 16#6f,   % o l - - - - c o
    16#6e, 16#6e, 16#65, 16#63, 16#74, 16#69, 16#6f, 16#6e,   % n n e c t i o n
    16#00, 16#00, 16#00, 16#0c, 16#63, 16#6f, 16#6e, 16#74,   % - - - - c o n t
    16#65, 16#6e, 16#74, 16#2d, 16#62, 16#61, 16#73, 16#65,   % e n t - b a s e
    16#00, 16#00, 16#00, 16#10, 16#63, 16#6f, 16#6e, 16#74,   % - - - - c o n t
    16#65, 16#6e, 16#74, 16#2d, 16#65, 16#6e, 16#63, 16#6f,   % e n t - e n c o
    16#64, 16#69, 16#6e, 16#67, 16#00, 16#00, 16#00, 16#10,   % d i n g - - - -
    16#63, 16#6f, 16#6e, 16#74, 16#65, 16#6e, 16#74, 16#2d,   % c o n t e n t -
    16#6c, 16#61, 16#6e, 16#67, 16#75, 16#61, 16#67, 16#65,   % l a n g u a g e
    16#00, 16#00, 16#00, 16#0e, 16#63, 16#6f, 16#6e, 16#74,   % - - - - c o n t
    16#65, 16#6e, 16#74, 16#2d, 16#6c, 16#65, 16#6e, 16#67,   % e n t - l e n g
    16#74, 16#68, 16#00, 16#00, 16#00, 16#10, 16#63, 16#6f,   % t h - - - - c o
    16#6e, 16#74, 16#65, 16#6e, 16#74, 16#2d, 16#6c, 16#6f,   % n t e n t - l o
    16#63, 16#61, 16#74, 16#69, 16#6f, 16#6e, 16#00, 16#00,   % c a t i o n - -
    16#00, 16#0b, 16#63, 16#6f, 16#6e, 16#74, 16#65, 16#6e,   % - - c o n t e n
    16#74, 16#2d, 16#6d, 16#64, 16#35, 16#00, 16#00, 16#00,   % t - m d 5 - - -
    16#0d, 16#63, 16#6f, 16#6e, 16#74, 16#65, 16#6e, 16#74,   % - c o n t e n t
    16#2d, 16#72, 16#61, 16#6e, 16#67, 16#65, 16#00, 16#00,   % - r a n g e - -
    16#00, 16#0c, 16#63, 16#6f, 16#6e, 16#74, 16#65, 16#6e,   % - - c o n t e n
    16#74, 16#2d, 16#74, 16#79, 16#70, 16#65, 16#00, 16#00,   % t - t y p e - -
    16#00, 16#04, 16#64, 16#61, 16#74, 16#65, 16#00, 16#00,   % - - d a t e - -
    16#00, 16#04, 16#65, 16#74, 16#61, 16#67, 16#00, 16#00,   % - - e t a g - -
    16#00, 16#06, 16#65, 16#78, 16#70, 16#65, 16#63, 16#74,   % - - e x p e c t
    16#00, 16#00, 16#00, 16#07, 16#65, 16#78, 16#70, 16#69,   % - - - - e x p i
    16#72, 16#65, 16#73, 16#00, 16#00, 16#00, 16#04, 16#66,   % r e s - - - - f
    16#72, 16#6f, 16#6d, 16#00, 16#00, 16#00, 16#04, 16#68,   % r o m - - - - h
    16#6f, 16#73, 16#74, 16#00, 16#00, 16#00, 16#08, 16#69,   % o s t - - - - i
    16#66, 16#2d, 16#6d, 16#61, 16#74, 16#63, 16#68, 16#00,   % f - m a t c h -
    16#00, 16#00, 16#11, 16#69, 16#66, 16#2d, 16#6d, 16#6f,   % - - - i f - m o
    16#64, 16#69, 16#66, 16#69, 16#65, 16#64, 16#2d, 16#73,   % d i f i e d - s
    16#69, 16#6e, 16#63, 16#65, 16#00, 16#00, 16#00, 16#0d,   % i n c e - - - -
    16#69, 16#66, 16#2d, 16#6e, 16#6f, 16#6e, 16#65, 16#2d,   % i f - n o n e -
    16#6d, 16#61, 16#74, 16#63, 16#68, 16#00, 16#00, 16#00,   % m a t c h - - -
    16#08, 16#69, 16#66, 16#2d, 16#72, 16#61, 16#6e, 16#67,   % - i f - r a n g
    16#65, 16#00, 16#00, 16#00, 16#13, 16#69, 16#66, 16#2d,   % e - - - - i f -
    16#75, 16#6e, 16#6d, 16#6f, 16#64, 16#69, 16#66, 16#69,   % u n m o d i f i
    16#65, 16#64, 16#2d, 16#73, 16#69, 16#6e, 16#63, 16#65,   % e d - s i n c e
    16#00, 16#00, 16#00, 16#0d, 16#6c, 16#61, 16#73, 16#74,   % - - - - l a s t
    16#2d, 16#6d, 16#6f, 16#64, 16#69, 16#66, 16#69, 16#65,   % - m o d i f i e
    16#64, 16#00, 16#00, 16#00, 16#08, 16#6c, 16#6f, 16#63,   % d - - - - l o c
    16#61, 16#74, 16#69, 16#6f, 16#6e, 16#00, 16#00, 16#00,   % a t i o n - - -
    16#0c, 16#6d, 16#61, 16#78, 16#2d, 16#66, 16#6f, 16#72,   % - m a x - f o r
    16#77, 16#61, 16#72, 16#64, 16#73, 16#00, 16#00, 16#00,   % w a r d s - - -
    16#06, 16#70, 16#72, 16#61, 16#67, 16#6d, 16#61, 16#00,   % - p r a g m a -
    16#00, 16#00, 16#12, 16#70, 16#72, 16#6f, 16#78, 16#79,   % - - - p r o x y
    16#2d, 16#61, 16#75, 16#74, 16#68, 16#65, 16#6e, 16#74,   % - a u t h e n t
    16#69, 16#63, 16#61, 16#74, 16#65, 16#00, 16#00, 16#00,   % i c a t e - - -
    16#13, 16#70, 16#72, 16#6f, 16#78, 16#79, 16#2d, 16#61,   % - p r o x y - a
    16#75, 16#74, 16#68, 16#6f, 16#72, 16#69, 16#7a, 16#61,   % u t h o r i z a
    16#74, 16#69, 16#6f, 16#6e, 16#00, 16#00, 16#00, 16#05,   % t i o n - - - -
    16#72, 16#61, 16#6e, 16#67, 16#65, 16#00, 16#00, 16#00,   % r a n g e - - -
    16#07, 16#72, 16#65, 16#66, 16#65, 16#72, 16#65, 16#72,   % - r e f e r e r
    16#00, 16#00, 16#00, 16#0b, 16#72, 16#65, 16#74, 16#72,   % - - - - r e t r
    16#79, 16#2d, 16#61, 16#66, 16#74, 16#65, 16#72, 16#00,   % y - a f t e r -
    16#00, 16#00, 16#06, 16#73, 16#65, 16#72, 16#76, 16#65,   % - - - s e r v e
    16#72, 16#00, 16#00, 16#00, 16#02, 16#74, 16#65, 16#00,   % r - - - - t e -
    16#00, 16#00, 16#07, 16#74, 16#72, 16#61, 16#69, 16#6c,   % - - - t r a i l
    16#65, 16#72, 16#00, 16#00, 16#00, 16#11, 16#74, 16#72,   % e r - - - - t r
    16#61, 16#6e, 16#73, 16#66, 16#65, 16#72, 16#2d, 16#65,   % a n s f e r - e
    16#6e, 16#63, 16#6f, 16#64, 16#69, 16#6e, 16#67, 16#00,   % n c o d i n g -
    16#00, 16#00, 16#07, 16#75, 16#70, 16#67, 16#72, 16#61,   % - - - u p g r a
    16#64, 16#65, 16#00, 16#00, 16#00, 16#0a, 16#75, 16#73,   % d e - - - - u s
    16#65, 16#72, 16#2d, 16#61, 16#67, 16#65, 16#6e, 16#74,   % e r - a g e n t
    16#00, 16#00, 16#00, 16#04, 16#76, 16#61, 16#72, 16#79,   % - - - - v a r y
    16#00, 16#00, 16#00, 16#03, 16#76, 16#69, 16#61, 16#00,   % - - - - v i a -
    16#00, 16#00, 16#07, 16#77, 16#61, 16#72, 16#6e, 16#69,   % - - - w a r n i
    16#6e, 16#67, 16#00, 16#00, 16#00, 16#10, 16#77, 16#77,   % n g - - - - w w
    16#77, 16#2d, 16#61, 16#75, 16#74, 16#68, 16#65, 16#6e,   % w - a u t h e n
    16#74, 16#69, 16#63, 16#61, 16#74, 16#65, 16#00, 16#00,   % t i c a t e - -
    16#00, 16#06, 16#6d, 16#65, 16#74, 16#68, 16#6f, 16#64,   % - - m e t h o d
    16#00, 16#00, 16#00, 16#03, 16#67, 16#65, 16#74, 16#00,   % - - - - g e t -
    16#00, 16#00, 16#06, 16#73, 16#74, 16#61, 16#74, 16#75,   % - - - s t a t u
    16#73, 16#00, 16#00, 16#00, 16#06, 16#32, 16#30, 16#30,   % s - - - - 2 0 0
    16#20, 16#4f, 16#4b, 16#00, 16#00, 16#00, 16#07, 16#76,   % - O K - - - - v
    16#65, 16#72, 16#73, 16#69, 16#6f, 16#6e, 16#00, 16#00,   % e r s i o n - -
    16#00, 16#08, 16#48, 16#54, 16#54, 16#50, 16#2f, 16#31,   % - - H T T P - 1
    16#2e, 16#31, 16#00, 16#00, 16#00, 16#03, 16#75, 16#72,   % - 1 - - - - u r
    16#6c, 16#00, 16#00, 16#00, 16#06, 16#70, 16#75, 16#62,   % l - - - - p u b
    16#6c, 16#69, 16#63, 16#00, 16#00, 16#00, 16#0a, 16#73,   % l i c - - - - s
    16#65, 16#74, 16#2d, 16#63, 16#6f, 16#6f, 16#6b, 16#69,   % e t - c o o k i
    16#65, 16#00, 16#00, 16#00, 16#0a, 16#6b, 16#65, 16#65,   % e - - - - k e e
    16#70, 16#2d, 16#61, 16#6c, 16#69, 16#76, 16#65, 16#00,   % p - a l i v e -
    16#00, 16#00, 16#06, 16#6f, 16#72, 16#69, 16#67, 16#69,   % - - - o r i g i
    16#6e, 16#31, 16#30, 16#30, 16#31, 16#30, 16#31, 16#32,   % n 1 0 0 1 0 1 2
    16#30, 16#31, 16#32, 16#30, 16#32, 16#32, 16#30, 16#35,   % 0 1 2 0 2 2 0 5
    16#32, 16#30, 16#36, 16#33, 16#30, 16#30, 16#33, 16#30,   % 2 0 6 3 0 0 3 0
    16#32, 16#33, 16#30, 16#33, 16#33, 16#30, 16#34, 16#33,   % 2 3 0 3 3 0 4 3
    16#30, 16#35, 16#33, 16#30, 16#36, 16#33, 16#30, 16#37,   % 0 5 3 0 6 3 0 7
    16#34, 16#30, 16#32, 16#34, 16#30, 16#35, 16#34, 16#30,   % 4 0 2 4 0 5 4 0
    16#36, 16#34, 16#30, 16#37, 16#34, 16#30, 16#38, 16#34,   % 6 4 0 7 4 0 8 4
    16#30, 16#39, 16#34, 16#31, 16#30, 16#34, 16#31, 16#31,   % 0 9 4 1 0 4 1 1
    16#34, 16#31, 16#32, 16#34, 16#31, 16#33, 16#34, 16#31,   % 4 1 2 4 1 3 4 1
    16#34, 16#34, 16#31, 16#35, 16#34, 16#31, 16#36, 16#34,   % 4 4 1 5 4 1 6 4
    16#31, 16#37, 16#35, 16#30, 16#32, 16#35, 16#30, 16#34,   % 1 7 5 0 2 5 0 4
    16#35, 16#30, 16#35, 16#32, 16#30, 16#33, 16#20, 16#4e,   % 5 0 5 2 0 3 - N
    16#6f, 16#6e, 16#2d, 16#41, 16#75, 16#74, 16#68, 16#6f,   % o n - A u t h o
    16#72, 16#69, 16#74, 16#61, 16#74, 16#69, 16#76, 16#65,   % r i t a t i v e
    16#20, 16#49, 16#6e, 16#66, 16#6f, 16#72, 16#6d, 16#61,   % - I n f o r m a
    16#74, 16#69, 16#6f, 16#6e, 16#32, 16#30, 16#34, 16#20,   % t i o n 2 0 4 -
    16#4e, 16#6f, 16#20, 16#43, 16#6f, 16#6e, 16#74, 16#65,   % N o - C o n t e
    16#6e, 16#74, 16#33, 16#30, 16#31, 16#20, 16#4d, 16#6f,   % n t 3 0 1 - M o
    16#76, 16#65, 16#64, 16#20, 16#50, 16#65, 16#72, 16#6d,   % v e d - P e r m
    16#61, 16#6e, 16#65, 16#6e, 16#74, 16#6c, 16#79, 16#34,   % a n e n t l y 4
    16#30, 16#30, 16#20, 16#42, 16#61, 16#64, 16#20, 16#52,   % 0 0 - B a d - R
    16#65, 16#71, 16#75, 16#65, 16#73, 16#74, 16#34, 16#30,   % e q u e s t 4 0
    16#31, 16#20, 16#55, 16#6e, 16#61, 16#75, 16#74, 16#68,   % 1 - U n a u t h
    16#6f, 16#72, 16#69, 16#7a, 16#65, 16#64, 16#34, 16#30,   % o r i z e d 4 0
    16#33, 16#20, 16#46, 16#6f, 16#72, 16#62, 16#69, 16#64,   % 3 - F o r b i d
    16#64, 16#65, 16#6e, 16#34, 16#30, 16#34, 16#20, 16#4e,   % d e n 4 0 4 - N
    16#6f, 16#74, 16#20, 16#46, 16#6f, 16#75, 16#6e, 16#64,   % o t - F o u n d
    16#35, 16#30, 16#30, 16#20, 16#49, 16#6e, 16#74, 16#65,   % 5 0 0 - I n t e
    16#72, 16#6e, 16#61, 16#6c, 16#20, 16#53, 16#65, 16#72,   % r n a l - S e r
    16#76, 16#65, 16#72, 16#20, 16#45, 16#72, 16#72, 16#6f,   % v e r - E r r o
    16#72, 16#35, 16#30, 16#31, 16#20, 16#4e, 16#6f, 16#74,   % r 5 0 1 - N o t
    16#20, 16#49, 16#6d, 16#70, 16#6c, 16#65, 16#6d, 16#65,   % - I m p l e m e
    16#6e, 16#74, 16#65, 16#64, 16#35, 16#30, 16#33, 16#20,   % n t e d 5 0 3 -
    16#53, 16#65, 16#72, 16#76, 16#69, 16#63, 16#65, 16#20,   % S e r v i c e -
    16#55, 16#6e, 16#61, 16#76, 16#61, 16#69, 16#6c, 16#61,   % U n a v a i l a
    16#62, 16#6c, 16#65, 16#4a, 16#61, 16#6e, 16#20, 16#46,   % b l e J a n - F
    16#65, 16#62, 16#20, 16#4d, 16#61, 16#72, 16#20, 16#41,   % e b - M a r - A
    16#70, 16#72, 16#20, 16#4d, 16#61, 16#79, 16#20, 16#4a,   % p r - M a y - J
    16#75, 16#6e, 16#20, 16#4a, 16#75, 16#6c, 16#20, 16#41,   % u n - J u l - A
    16#75, 16#67, 16#20, 16#53, 16#65, 16#70, 16#74, 16#20,   % u g - S e p t -
    16#4f, 16#63, 16#74, 16#20, 16#4e, 16#6f, 16#76, 16#20,   % O c t - N o v -
    16#44, 16#65, 16#63, 16#20, 16#30, 16#30, 16#3a, 16#30,   % D e c - 0 0 - 0
    16#30, 16#3a, 16#30, 16#30, 16#20, 16#4d, 16#6f, 16#6e,   % 0 - 0 0 - M o n
    16#2c, 16#20, 16#54, 16#75, 16#65, 16#2c, 16#20, 16#57,   % - - T u e - - W
    16#65, 16#64, 16#2c, 16#20, 16#54, 16#68, 16#75, 16#2c,   % e d - - T h u -
    16#20, 16#46, 16#72, 16#69, 16#2c, 16#20, 16#53, 16#61,   % - F r i - - S a
    16#74, 16#2c, 16#20, 16#53, 16#75, 16#6e, 16#2c, 16#20,   % t - - S u n - -
    16#47, 16#4d, 16#54, 16#63, 16#68, 16#75, 16#6e, 16#6b,   % G M T c h u n k
    16#65, 16#64, 16#2c, 16#74, 16#65, 16#78, 16#74, 16#2f,   % e d - t e x t -
    16#68, 16#74, 16#6d, 16#6c, 16#2c, 16#69, 16#6d, 16#61,   % h t m l - i m a
    16#67, 16#65, 16#2f, 16#70, 16#6e, 16#67, 16#2c, 16#69,   % g e - p n g - i
    16#6d, 16#61, 16#67, 16#65, 16#2f, 16#6a, 16#70, 16#67,   % m a g e - j p g
    16#2c, 16#69, 16#6d, 16#61, 16#67, 16#65, 16#2f, 16#67,   % - i m a g e - g
    16#69, 16#66, 16#2c, 16#61, 16#70, 16#70, 16#6c, 16#69,   % i f - a p p l i
    16#63, 16#61, 16#74, 16#69, 16#6f, 16#6e, 16#2f, 16#78,   % c a t i o n - x
    16#6d, 16#6c, 16#2c, 16#61, 16#70, 16#70, 16#6c, 16#69,   % m l - a p p l i
    16#63, 16#61, 16#74, 16#69, 16#6f, 16#6e, 16#2f, 16#78,   % c a t i o n - x
    16#68, 16#74, 16#6d, 16#6c, 16#2b, 16#78, 16#6d, 16#6c,   % h t m l - x m l
    16#2c, 16#74, 16#65, 16#78, 16#74, 16#2f, 16#70, 16#6c,   % - t e x t - p l
    16#61, 16#69, 16#6e, 16#2c, 16#74, 16#65, 16#78, 16#74,   % a i n - t e x t
    16#2f, 16#6a, 16#61, 16#76, 16#61, 16#73, 16#63, 16#72,   % - j a v a s c r
    16#69, 16#70, 16#74, 16#2c, 16#70, 16#75, 16#62, 16#6c,   % i p t - p u b l
    16#69, 16#63, 16#70, 16#72, 16#69, 16#76, 16#61, 16#74,   % i c p r i v a t
    16#65, 16#6d, 16#61, 16#78, 16#2d, 16#61, 16#67, 16#65,   % e m a x - a g e
    16#3d, 16#67, 16#7a, 16#69, 16#70, 16#2c, 16#64, 16#65,   % - g z i p - d e
    16#66, 16#6c, 16#61, 16#74, 16#65, 16#2c, 16#73, 16#64,   % f l a t e - s d
    16#63, 16#68, 16#63, 16#68, 16#61, 16#72, 16#73, 16#65,   % c h c h a r s e
    16#74, 16#3d, 16#75, 16#74, 16#66, 16#2d, 16#38, 16#63,   % t - u t f - 8 c
    16#68, 16#61, 16#72, 16#73, 16#65, 16#74, 16#3d, 16#69,   % h a r s e t - i
    16#73, 16#6f, 16#2d, 16#38, 16#38, 16#35, 16#39, 16#2d,   % s o - 8 8 5 9 -
    16#31, 16#2c, 16#75, 16#74, 16#66, 16#2d, 16#2c, 16#2a,   % 1 - u t f - - -
    16#2c, 16#65, 16#6e, 16#71, 16#3d, 16#30, 16#2e           % - e n q - 0 -
>>).
