: ? ( adr -- ) @ . ;

: here h @ ;

: , ( n -- ) here ! cell allot ;

: /mod ( a b -- rem quot) over over mod rot rot div ;

: 0= ( n -- f) 0 = ;

: not ( n -- f) 0= if 1 else 0 endif ;

: ?dup ( n -- ) dup dup 0= if drop endif ;

: +! ( n adr -- ) dup @ rot + swap ! ;

: <= ( a b -- f) over over  <  if drop drop 1 else = endif ;

: >= ( a b -- f) over over  >  if drop drop 1 else = endif ;

: double ( n -- n) 2 * ;

: tell-sign ( n -- ) 2 mod 0= if ." even" else ." odd" endif ;

: rep ( n -- ) dup 0 >= if 0 do i . loop endif ;

variable x
