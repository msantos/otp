%%% -*- erlang-indent-level: 2 -*-
%%%
%%% %CopyrightBegin%
%%% 
%%% Copyright Ericsson AB 2006-2009. All Rights Reserved.
%%% 
%%% Licensed under the Apache License, Version 2.0 (the "License");
%%% you may not use this file except in compliance with the License.
%%% You may obtain a copy of the License at
%%%
%%%     http://www.apache.org/licenses/LICENSE-2.0
%%%
%%% Unless required by applicable law or agreed to in writing, software
%%% distributed under the License is distributed on an "AS IS" BASIS,
%%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%%% See the License for the specific language governing permissions and
%%% limitations under the License.
%%% 
%%% %CopyrightEnd%
%%%
%%% Linear Scan register allocator for ARM

-module(hipe_arm_ra_ls).
-export([ra/3]).

ra(Defun, SpillIndex, Options) ->
  NewDefun = Defun, %% hipe_${ARCH}_ra_rename:rename(Defun,Options),
  CFG = hipe_arm_cfg:init(NewDefun),
  SpillLimit = hipe_arm_specific:number_of_temporaries(CFG),
  alloc(NewDefun, SpillIndex, SpillLimit, Options).

alloc(Defun, SpillIndex, SpillLimit, Options) ->
  CFG = hipe_arm_cfg:init(Defun),
  {Coloring, _NewSpillIndex} =
    regalloc(
      CFG,
      hipe_arm_registers:allocatable_gpr()--
      [hipe_arm_registers:temp3(),
       hipe_arm_registers:temp2(),
       hipe_arm_registers:temp1()],
      [hipe_arm_cfg:start_label(CFG)],
      SpillIndex, SpillLimit, Options,
      hipe_arm_specific),
  {NewDefun, _DidSpill} =
    hipe_arm_ra_postconditions:check_and_rewrite(
      Defun, Coloring, 'linearscan'),
  TempMap = hipe_temp_map:cols2tuple(Coloring, hipe_arm_specific),
  {SpillMap, _NewSpillIndex2} =
    hipe_spillmin:stackalloc(CFG, [], SpillIndex, Options,
			     hipe_arm_specific, TempMap),
  Coloring2 =
    hipe_spillmin:mapmerge(hipe_temp_map:to_substlist(TempMap), SpillMap),
  {NewDefun, Coloring2}.

regalloc(CFG, PhysRegs, Entrypoints, SpillIndex, DontSpill, Options, Target) ->
  hipe_ls_regalloc:regalloc(
    CFG, PhysRegs, Entrypoints, SpillIndex, DontSpill, Options, Target).
