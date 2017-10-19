extensions [ nw ] ;; network extension.
;; NOTE - the default nw that comes with Netlogo 6.0.2 is, as of writing, actually meant for Netlogo 5 and breaks with 6.
;; Download from here, and replace your nw folder (Netlogo / app / extensions ) with this stuff: https://github.com/NetLogo/NW-Extension

globals [
  destination-who
  last-patch
  last-block
  nearest-distance-to-last-patch
  square-length
  district-count
  next-xcor
  next-ycor
  net-partisan-score-of-neighbors
  any-blocks-changed?
  moderator-count
  loop-count
  blue-districts
  lean-blue-districts
  red-districts
  lean-red-districts
  split-districts
  red-wins
  red-likely-wins
  blue-wins
  blue-likely-wins
  too-close-to-call-elections
  district-cache
  district-list
  new-district-list
  good-swap-found?
  backout-district
  continuous?
  compact?
  similar-sizes?
  mean-path-length-cache
  current-mean-path-length
  new-mean-path-length
  perimeter-area-ratio-cache
  current-perimeter-area-ratio
  new-perimeter-area-ratio
  swaps-attempted
  continuity-rejections
  compactness-rejections
  size-rejections
]

blocks-own [
  partisan-score
  neighbor-count
]

patches-own [
  district
  last-election-outcome
  mean-path-length
  perimeter-area-ratio
]

breed [ blocks block ]

to setup
  clear-all
  set red-wins 0
  set red-likely-wins 0
  set blue-wins 0
  set blue-likely-wins 0
  set too-close-to-call-elections 0
  set-default-shape blocks "circle"
  set square-length 15 ;; I optimistically made this a variable, but if you change it to anything else everything will break horribly
  set district-count 9 ;; ditto for this one
  create-new-blocks-square ;; Creates vote blocks in a square-length square.
  ;; Generating non-square block arrangements isn't hard - see orphan procedure create-new-blocks-linear - but district/viz code need a lot of robustness to support it.
  link-blocks ;; Link orthagionally adjacent blocks
  while [ any-blocks-changed? = true ] [ clump ] ;; Make blocks surronded by one color more likely to be that color
  moderate-score ;; Once we hit clumping equilibirum, make partisan-score values continious (but on their same side of .5). Moderation scales with non-matching neighbors.
  color-blocks ;; color blocks according to their scores.
  create-initial-districts-square ;; Make the starting 9 districts in the square subgraphs
  color-districts ;; give districts color, and color contested edges black ("district 0")
  update-reporters ;; update the values we're tying monitors/graphs to
  reset-ticks
end

to go
  ;; clear out per-tick variables
  set swaps-attempted 0
  set continuity-rejections 0
  set compactness-rejections 0
  set size-rejections 0
  set good-swap-found? false ;; so we will properly loop until we find a good swap
  while [ good-swap-found? = false ] [ set swaps-attempted swaps-attempted + 1 swap-block ] ;; call swap-block until a swap is accepted
  color-districts
  update-reporters
  tick
end


to clump ;;
  set any-blocks-changed? false ;; so we terminate on a loop where match neighbors does no change
  ask blocks
  [ set net-partisan-score-of-neighbors partisan-score ;; the average partisan score of neighbors. This is before moderation, so all scores are 0 or 1. Start with your own score.
    ask link-neighbors
    [ set net-partisan-score-of-neighbors net-partisan-score-of-neighbors + partisan-score ] ;; add score of each link neighbor
    set net-partisan-score-of-neighbors net-partisan-score-of-neighbors / ( ( count link-neighbors ) + 1) ;; on average, are you and your neighbors red or blue?
    if net-partisan-score-of-neighbors > .5 and partisan-score = 0 [ set partisan-score 1 set any-blocks-changed? true ] ;; reds in blue neighborhoods go blue
    if net-partisan-score-of-neighbors < .5 and partisan-score = 1 [ set partisan-score 0 set any-blocks-changed? true ] ;; blues in red neighborhoods go red
  ]
end

to create-new-blocks-square ;; make a square set of blocks
 set next-ycor max-pycor
 repeat square-length
  [ set next-xcor min-pxcor
    set next-ycor next-ycor - 2
    repeat square-length
    [ set next-xcor next-xcor + 2
      ask patch next-xcor next-ycor [ sprout-block-from-patch]
    ]
  ]
end

to link-blocks ;; links each block with it's nearest neighbors
  ask blocks
  [ let nearest-neighbor-distance distance min-one-of other blocks [ distance myself ] ;; this will need to be more robust for more irregular worlds
    create-links-with other blocks in-radius nearest-neighbor-distance
  ]
end

to color-blocks ;; color each block according to partisan score
  ;; darker red the farther below .5 you are, darker blue the farther above .5 you are
  ;; Netlogo colors are weird, so just believe me that this works
  ask blocks [ ifelse partisan-score > .5 [ set color scale-color blue partisan-score 1.5 .5 ] [ set color scale-color red partisan-score -.5 .5 ] ]
end

to sprout-block-from-patch ;; function we call to spawn a block given that we're asking a patch
  ;; it may seem like this doesn't need its own procedure, but if we add more agential concerns this will be a smart modulariziation
  sprout-blocks 1 [ set partisan-score random 2 ]
end


to moderate-score ;; take the initial boolean partisan scores and make them floats, but floats that still sit on their half of .5
  ;; This is just a "gut feel" function to make a nice looking distribution - change it to whatever you want.
  ;; Just remember - strict 0s and 1's go in to moderator score, the partisan-score values you want come out.
ask blocks
  [
    ifelse partisan-score = 0
    [ set moderator-count count link-neighbors with [ partisan-score = 1 ] ] [ set moderator-count count link-neighbors with [ partisan-score = 0 ] ]
  ]
  ;; moderator count is the count of non-matching neighbors - we'll moderate these blocks more
ask blocks
      [ set moderator-count ( ( moderator-count + ( intrinsic-moderation * 10 ) ) / 10 )
        ifelse partisan-score = 0
      [set partisan-score random-float moderator-count ] ;; former zeroes get some score added accoridng to moderator float
      [set partisan-score 1 - random-float moderator-count ] ;; former ones get some score subtracted according to moderator float
  ]
end

to create-initial-districts-square ;; hard coded districts for the subgraph of a 15x15 square.
  ask patches with [ pxcor >= -14 and pxcor <= -6 and pycor >= 6 and pycor <= 14 ] [ set district 1 ]
  ask patches with [ pxcor >= -4 and pxcor <= 4 and pycor >= 6 and pycor <= 14 ] [ set district 2 ]
  ask patches with [ pxcor >= 6 and pxcor <= 14 and pycor >= 6 and pycor <= 14 ] [ set district 3 ]
  ask patches with [ pxcor >= -14 and pxcor <= -6 and pycor >= -4 and pycor <= 4 ] [ set district 4 ]
  ask patches with [ pxcor >= -4 and pxcor <= 4 and pycor >= -4 and pycor <= 4 ] [ set district 5 ]
  ask patches with [ pxcor >= 6 and pxcor <= 14 and pycor >= -4 and pycor <= 4 ] [ set district 6 ]
  ask patches with [ pxcor >= -14 and pxcor <= -6 and pycor >= -14 and pycor <= -6 ] [ set district 7 ]
  ask patches with [ pxcor >= -4 and pxcor <= 4 and pycor >= -14 and pycor <= -6 ] [ set district 8 ]
  ask patches with [ pxcor >= 6 and pxcor <= 14 and pycor >= -14 and pycor <= -6 ] [ set district 9 ]
end

to color-districts ;; color to update districts and edges.
  ;; Here's why this code breaks if don't use the 15x15 sqaure: we want to have districts be all one color.
  ;; For the patches with a block on them, this is easy. But what about the space in-between blocks?
  ;; We have constructed our model juuuuust so that links happen to have a "logical patch".
  ;; Then, we can define our viz code to check the links on top of their logical patches.
  ;; If a link is linked to two blocks in the same district, give the logical patch that district - 0 otherwise.
  ;; This looks nice, but it ONLY works using logical patches - links don't interact with patches in the code itself, just via our hack.
  ;; So, if you expand the model for non-square districts, you can color the patches with blocks easily enough, but you'll need to figure out how to color the other space.
  ;; And logical patches aren't generally well-defined, so you'll need to figure something else out.

  ask patches with [ pxcor mod 2 = 1 and -15 < pxcor and pxcor < 15 and -15 < pycor and pycor < 15 ] ;; logical patches of horizontal links
    [ let patch-x pxcor
      let patch-y pycor
      let leftdistrict [ district] of patch ( patch-x - 1 ) patch-y ;; check left patch
      let rightdistrict [ district ] of patch ( patch-x + 1 ) patch-y ;; check right patch
      ifelse leftdistrict = rightdistrict [ set district leftdistrict ] [ set district 0 ] ;; take district of patches if they match, 0 otherwise
    ]

    ask patches with [ pycor mod 2 = 1 and -15 < pxcor and pxcor < 15 and -15 < pycor and pycor < 15 ] ;; logical patches of vertical links
    [ let patch-x pxcor
      let patch-y pycor
      let updistrict [ district] of patch patch-x ( patch-y + 1 )
      let downdistrict [ district ] of patch patch-x ( patch-y - 1 )
      ifelse updistrict = downdistrict [ set district updistrict ] [ set district 0 ]
    ]
    ask patches with [ district = 0 ] [ set pcolor black ] ;; there is no real "district 0" - this is the set of logical patches of links between blocks with different districts
    ;; the other colors have no special meaning, just 9 colors you can make out reds and blues on
    ask patches with [ district = 1 ] [ set pcolor pink ]
    ask patches with [ district = 2 ] [ set pcolor green ]
    ask patches with [ district = 3 ] [ set pcolor orange ]
    ask patches with [ district = 4 ] [ set pcolor violet ]
    ask patches with [ district = 5 ] [ set pcolor magenta ]
    ask patches with [ district = 6 ] [ set pcolor yellow ]
    ask patches with [ district = 7 ] [ set pcolor brown ]
    ask patches with [ district = 8 ] [ set pcolor gray ]
    ask patches with [ district = 9 ] [ set pcolor turquoise ]
end

to update-reporters ;; update our per-tick measures and plots
  set district-list []
  set blue-districts 0 ;; blue districts are districts where blue wins even if every split vote is red
  set lean-blue-districts 0 ;; lean-blue districts are districts where blue wins, but not if all split votes go red
  set red-districts 0 ;;  red districts are districts where red wins even if every split vote is blue
  set lean-red-districts 0 ;; lean-red districts are districts where red wins, but not if all split votes go blue
  set split-districts 0 ;; split districts have the same count of "solid" votes of both kinds
  set loop-count 1
  if compactness-measure = "mean path length" [ set mean-path-length-cache 0 ]
  if compactness-measure = "perimeter-area ratio" [ set perimeter-area-ratio-cache 0 ]
  repeat district-count
  [
    set district-list lput count blocks-on patches with [ district = loop-count ] district-list ;; get count of blocks in district, so we can analyze population
    let blue-votes 0
    let lean-blue-votes 0
    let red-votes 0
    let lean-red-votes 0
    let outcome ""
    ask blocks-on patches with [ district = loop-count ] ;poll each block in the district
    [
      let partisan-net partisan-score - .5
      if partisan-score > .5
        [ ifelse abs ( partisan-net ) > uncertainty-threshold
          [ set blue-votes blue-votes + 1 ] [ set lean-blue-votes lean-blue-votes + 1 ] ] ;; to be a true blue vote, you must be at least uncertainty-threshold above .5
      if partisan-score < .5
        [ ifelse abs ( partisan-net ) > uncertainty-threshold
          [ set red-votes red-votes + 1 ] [ set lean-red-votes lean-red-votes + 1 ] ] ;; to be a true red vote, you must be at least uncertainty-threshold below .5
    ]
    if blue-votes + lean-blue-votes > red-votes + lean-red-votes
    [ ifelse blue-votes > red-votes + lean-red-votes + lean-blue-votes
      [ set blue-districts blue-districts + 1 set outcome "blue" ] [ set lean-blue-districts lean-blue-districts + 1 set outcome "lean-blue"] ]
    if red-votes + lean-red-votes > blue-votes + lean-blue-votes
    [ ifelse red-votes > blue-votes + lean-blue-votes + lean-red-votes
      [ set red-districts red-districts + 1 set outcome "red"] [ set lean-red-districts lean-red-districts + 1 set outcome "lean-red" ] ]
    if outcome = "" [ set split-districts split-districts + 1 set outcome "split" ] ;; a district is split if none of the four previous outcomes happen
    if compactness-measure = "mean path length" [ find-mean-path-length ]
    if compactness-measure = "perimeter-area ratio" [ find-perimeter-area-ratio ]
      ask patches with [ district = loop-count ] [ set last-election-outcome outcome ]
   set loop-count loop-count + 1
  ]
  let election-result? false ;; we set this so we can define a too-close to call election by the measure of no other result occuring
  if ( red-districts + lean-red-districts ) > ( blue-districts + lean-blue-districts ) [
    ifelse red-districts > ( blue-districts + lean-blue-districts + lean-red-districts )
    [ set red-wins red-wins + 1  set election-result? true ] [ set red-likely-wins red-likely-wins + 1 set election-result? true ] ]
  if ( blue-districts + lean-blue-districts ) > ( red-districts + lean-red-districts ) [
    ifelse blue-districts > ( red-districts + lean-red-districts + lean-blue-districts )
    [ set blue-wins blue-wins + 1  set election-result? true ] [ set blue-likely-wins blue-likely-wins + 1 set election-result? true ] ]
  if election-result? = false [ set too-close-to-call-elections too-close-to-call-elections + 1 ]
  if compactness-measure = "mean path length" [ set current-mean-path-length mean-path-length-cache / district-count ] ;; turn measure into an average
  if compactness-measure = "perimeter-area ratio" [ set current-perimeter-area-ratio perimeter-area-ratio-cache / district-count ] ;; turn measure into an average
end

to swap-block ;; per-tick code that moves blocks from one district to another
  ;; We choose one contested edge and pretend one block joined the district of the other
  ;; We undo the move if it fails one of our tests, and accept the move if it doesn't
  set compact? false ;; we need to clear our these variables per swap-block call, not just per-loop
  set continuous? false
  set similar-sizes? false
  ask one-of links with [ [ district ] of end1 != [ district ] of end2 ] ;; pick a conflicted edge
  [ ask one-of both-ends [ set district-cache district ;; cache the value of one edge
      ask other-end [ ;; make the other end switch
       ask patch-here [
         set backout-district district ;; have the patch hold on to the old district, in case this swap isn't valid
         set district district-cache ;; but for now, accept the swap
         ]
      calculate-impact-of-swap ;; check continuity and whatever score functions you like
      ifelse continuous? = true and compact? = true and similar-sizes? = true ;; did the swap pass our tests?
      [ set good-swap-found? true ] ;; if yes, the swap is now canon. stop looping this tick
      [ ask patch-here [ set district backout-district ] ;; if not, undo the swap for the block and its patch
        if continuous? = false [ set continuity-rejections continuity-rejections + 1 ] ;; record if we rejected the swap due to continuitiy
        if compact? = false [ set compactness-rejections compactness-rejections + 1 ] ;; record if we rejected the swap on compactness
        if similar-sizes? = false [ set size-rejections size-rejections + 1 ] ;; record if we rejected the swap on population standard deviation
  ] ] ] ]
end

to calculate-impact-of-swap
  set new-district-list []
  ;; the continuity test is absolute - we reject all swaps that break it.
  ;; Luckily for computation, we don't need to check the whole network, just the old district.
  ;; If this swap makes the old district have two components, discard it
  nw:set-context ( blocks-on patches with [ district = backout-district ] ) links
  if length nw:weak-component-clusters = 1 [ set continuous? true ] ;; old district must still be in one piece.
  if continuous? = true
  ;; Why do the other checks inside this one, instead of combining for short-circuiting?
  ;; So you can have score functions that rely on continious district chunks without causing crashes.
  [
  set loop-count 1
  if compactness-measure = "mean path length" [ set mean-path-length-cache 0 ]
  if compactness-measure = "perimeter-area ratio" [ set perimeter-area-ratio-cache 0 ]
  repeat district-count
    [  set new-district-list lput count blocks-on patches with [ district = loop-count ] new-district-list
       if compactness-measure = "mean path length" [ find-mean-path-length ]
       if compactness-measure = "perimeter-area ratio" [ find-perimeter-area-ratio ]
       set loop-count loop-count + 1
    ]
  if compactness-measure = "mean path length"
  [ set new-mean-path-length mean-path-length-cache / district-count
    let path-difference current-mean-path-length - new-mean-path-length ;; This is how much better the new graph is for path length than the old.
    ;; If we reduced path length, this measure will accept the swap - if we didn't, we roll the random-normal dice to see if we'll let it slip by
    if path-difference > 0 or ( random-normal ( ( path-difference * 2 ) + compactness-leniency ) 1 > 0 ) [ set compact? true ] ]
  if compactness-measure = "perimeter-area ratio"
  [ set new-perimeter-area-ratio perimeter-area-ratio-cache / district-count
    let ratio-difference current-perimeter-area-ratio - new-perimeter-area-ratio ;; This is how much better the new graph is for perimeter-area ratio than the old.
    ;; If we reduced perimeter-area ratio this measure will accept the swap - if we didn't, we roll the random-normal dice to see if we'll let it slip by
    if ratio-difference > 0 or ( random-normal ( ( ratio-difference  * 20 ) + compactness-leniency ) 1 > 0 ) [ set compact? true ] ] ;; multiply by ten since ratios are smaller
  let deviation-difference standard-deviation district-list - standard-deviation new-district-list ;; this is how much better the new population deviation is
  ;; If we reduced population standard deviation this measure will accept the swap - if we didn't, we roll the random-normal dice to see if we'll let it slip by
    if deviation-difference > 0 or ( random-normal ( ( deviation-difference * 2 ) + population-similarity-leniency ) 1 > 0 ) [ set similar-sizes? true ]
  ]
end

to find-mean-path-length ;; A hacky compactness measure - average path length of each district, averaged by district count
  ;; This is not very agential and resets nw context each call so it degrades performance a fair bit
  nw:set-context ( blocks-on patches with [ district = loop-count] ) links ;; have nw look at only the district in question
  let district-mean-path-length nw:mean-path-length  ;; find the mean path length for that district
  ask patches with [ district = loop-count ] [ set mean-path-length district-mean-path-length set perimeter-area-ratio "Not Calculated" ]
  set mean-path-length-cache mean-path-length-cache + district-mean-path-length ;; update the cached sum
end

to find-perimeter-area-ratio ;; A computationally simple compactness measure - all perimeter / all area
  let perimeter-blocks 0
  let area-blocks 0
  ask blocks-on patches with [ district = loop-count ]
  [ set area-blocks area-blocks + 1
    if any? neighbors4 with [ district != loop-count ] [ set perimeter-blocks perimeter-blocks + 1 ] ;; you are a perimeter block if any of your neighbors doesn't match
  ]
  let district-perimeter-area-ratio ( perimeter-blocks / area-blocks )
  ask patches with [ district = loop-count ] [  set perimeter-area-ratio district-perimeter-area-ratio set mean-path-length "Not Calculated" ]
  set perimeter-area-ratio-cache perimeter-area-ratio-cache + district-perimeter-area-ratio
end

to create-new-blocks-linear ;; orphan procedure that is never called, but starts to sketch non-square block generation.
  ;; expanding this is easy, but remember, it's the districting and especially the viz code that require exactly a 15x15 square.
  ask one-of patches
  [ sprout-blocks 1 [ set last-block self ] ;; spawn a random block smomewhere
    set last-patch self ]
  repeat 49
  [ set nearest-distance-to-last-patch min [ distance last-patch ] of patches with [ count blocks-here + count blocks-on neighbors = 0 ] ;; find distance of nearest empty patch
   ask one-of patches with [ count blocks-here + count blocks-on neighbors = 0  and distance last-patch = nearest-distance-to-last-patch ] ;; ask a patch at that distance...
    [ sprout-block-from-patch ;; to spawn the next block, and repeat
      set last-patch self ]
  ]
end

to bound-partisan-score ;; orphan procedure that is never called. Just here in case you want to mess with partisan score
  ;; no matter what weird stuff you do, it ultimately MUST be between 0 and 1
  if partisan-score > 1 [ set partisan-score 1 ]
  if partisan-score < 0 [ set partisan-score 0 ]
end
@#$#@#$#@
GRAPHICS-WINDOW
112
10
780
679
-1
-1
20.0
1
10
1
1
1
0
0
0
1
-16
16
-16
16
0
0
1
ticks
30.0

BUTTON
9
13
72
46
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
783
195
880
240
Blue Districts
blue-districts
17
1
11

MONITOR
783
242
882
287
Red Districts
red-districts
17
1
11

MONITOR
781
291
879
336
Split Districts
split-districts
17
1
11

BUTTON
9
54
72
87
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
6
93
83
126
go-once
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
2
422
106
467
Mean District Pop
mean district-list
17
1
11

MONITOR
3
473
107
518
Max District Pop
max district-list
17
1
11

MONITOR
3
375
106
420
Min District Pop
min district-list
17
1
11

SLIDER
789
492
971
525
uncertainty-threshold
uncertainty-threshold
.00
.5
0.2
.05
1
NIL
HORIZONTAL

MONITOR
881
195
981
240
Lean Blue Districts
lean-blue-districts
17
1
11

MONITOR
882
241
979
286
Lean Red Districts
lean-red-districts
17
1
11

MONITOR
3
142
103
187
NIL
swaps-attempted
17
1
11

SLIDER
788
529
972
562
compactness-leniency
compactness-leniency
-2
2
0.0
.25
1
NIL
HORIZONTAL

SLIDER
787
567
972
600
population-similarity-leniency
population-similarity-leniency
-2
2
0.0
.25
1
NIL
HORIZONTAL

MONITOR
4
194
87
239
cont. rejects
continuity-rejections
17
1
11

MONITOR
2
244
90
289
comp. rejects
compactness-rejections
17
1
11

MONITOR
5
297
85
342
pop. rejects
size-rejections
17
1
11

PLOT
983
206
1271
381
Population Standard Deviation Over Time
NIL
NIL
0.0
10.0
0.0
2.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot standard-deviation district-list"

PLOT
981
395
1276
561
Compactness Measure over Time
NIL
NIL
0.0
10.0
3.0
4.0
true
false
"if compactness-measure = \"mean path length\" [ set-plot-y-range 3 4 ]\nif compactness-measure = \"perimeter-area ratio\" [ set-plot-y-range .5 1 ]" ""
PENS
"default" 1.0 0 -16777216 true "" "if compactness-measure = \"mean path length\" [ plot current-mean-path-length ]\nif compactness-measure = \"perimeter-area ratio\" [ plot current-perimeter-area-ratio ]"

PLOT
790
10
1266
190
Proportion of Election Results Over Time
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Blue Likely Win" 1.0 0 -11033397 true "" "plot blue-likely-wins / ( ticks + 1 )"
"Blue Win" 1.0 0 -13345367 true "" "plot blue-wins / ( ticks + 1 )"
"Red Likely Win" 1.0 0 -1604481 true "" "plot red-likely-wins / ( ticks + 1 )"
"Red Win" 1.0 0 -2674135 true "" "plot red-wins / ( ticks + 1 )"
"Too Close To Call" 1.0 0 -7500403 true "" "plot too-close-to-call-elections / ( ticks + 1 )"

PLOT
978
573
1276
710
Swaps Attempted Per Success Over Time
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot swaps-attempted"

CHOOSER
787
611
950
656
compactness-measure
compactness-measure
"perimeter-area ratio" "mean path length"
0

TEXTBOX
797
666
947
726
You must hit Setup after changing compactness measure. 
12
0.0
1

SLIDER
791
455
970
488
intrinsic-moderation
intrinsic-moderation
0
.5
0.3
.05
1
%
HORIZONTAL

@#$#@#$#@
## Version Information
This is Version 1.0 of NetDistrict.

## What Is NetDistrict?
Netdistrict is a Netlogo model that takes a small world of voter blocks, puts them in to districts, and then randomly fusses with those districts according to some basic scoring functions. Right now, it's mostly a toy to play with, but a lot of grunt work is out of the way if you want to try to do serious analysis with this sort of model. 

## Why Netlogo?

Agent-based modeling offers some interesting design patterns, since both the links and the blocks (ie census blocks, VTDs, wards - whatever your unit of districting is) are modeled as agentsets. While our intuition says that the voters should be agents, by modeling blocks as agents, we can take the criteria of map building and express those criteria as agential preferences. This lets us think about redistricting locally, on the margins of the potential change, in combination with map-wide metrics. Will this be useful? Who knows, but now you've got the tools to find out.

### Wait, so this whole model might be totally pointless?
You get what you paid for, buddy.

## How does it work right now?

### Setup

On setup, Netdistrict starts by creating a 15x15 square of voter blocks. Currently, this is a hard-coded requirement. It would be easy to spawn blocks in other shapes, but having the districts and visualizations work in arbitrary conditions would be really tricky. I left  more detail in the comments of the code, especially color-districts. 

 These blocks are assigned a partisan-score of 0 (colored red) or 1 (colored blue). Then, the following clumping algorithm is ran:

> Take your partisan score, plus the sum of your neighbors. (Note that here and throughout, "neighbor" means the blocks that are linked to you. Currently, these are your orthogonal neighbors.) Average the scores by dividing by the count of you plus your neighbors. If the average is on one side of .5 and your score is on the other, change to the other value. Repeat until no blocks flip when running this algorithm.

After the partisan values are calculated, they are moderated to be more continuous. Each block starts with intrinsic-moderation (set by a slider in the Interface tab) and adds .1 for each opposite neighbor. For blocks with partisan-score 0, a random floating point number between 0 and this value is added to their partisan-score. For blocks with partisan-score 1, this value is instead subtracted from their partisan-score.

Then, the patches (and consequently, the blocks) are assigned nine starting districts by taking the nine 5x5 subgraphs that collectively span the space.

An election is held upon setup, as well as every tick.

### Election Rules

One district at a time, each block's partisan-score is evaluated.

>If a partisan-score is below .5 by a margin greater than uncertainty-threshold, it's called a red vote. If a partisan-score is below .5, but by a margin less than uncertainty-threshold (set by a slider in the Interface tab), it's called a lean-red vote. Similarly, partisan-scores more than uncertainty-threshold above .5 are blue votes, whereas votes less than uncertainty-threshold above .5 are lean-blue votes.

Once we've tallied all the votes for a given district, we can figure out the overall result for that district.

>If the red votes outnumber the blue, lean-blue, and lean-red votes, it's a red district.
If that's not true, but the red votes plus the lean-red votes outnumber the blue-votes plus lean-blue votes, it's a lean-red district. 
If the blue votes outnumber the red, lean-red, and lean-blue votes, it's a blue district.
If that's not true, but the blue votes plus the lean-blue votes outnumber the red-votes plus lean-red votes, it's a lean-blue district.
If none of those four outcomes happen, it's a "split district". 

The value of the last tallying of a district is stored in each patch of that district, to make it easier to validate.

Once each district's value is determined, we can figure out the overall election result.

>If red districts outnumber all other districts combined, the election is a red win.
If red districts plus lean-red districts outnumber all other districts combined, the election is a red likely win.
If blue districts outnumber all other districts combined, the election is a blue win.
If blue districts plus lean-blue districts outnumber all districts combined, the election is a blue likely win.
If none of those four outcomes happen, the election is too close to call.

### Go (what happens each tick)

We pick one contested edge at random (ie, a link that connects two blocks in different districts). Then, one block is randomly chosen to match the other one.

First, we check whether this splits the old district into more than one component. If it does, we reject the swap.

Then, we check our population and compactness measures. Currently, there is only one population measure - standard deviation. We want the districts to have equal population, so lower is better. There are two compactness measures you can choose between using the chooser on the Interface tab - perimeter-area ratio and mean path length. Perimeter-area ratio is a measure of how much "outside" a district has - since this is often evidence of trying to include faraway districts while excluding more "sensible" closer ones out of some nefarious intent, lower is better. Mean path length looks for the same phenomena: a long, artificial "tendril" to a district will increase the main path length. Note that mean path length is substantially slower than perimeter-area ratio. That's because the latter is an agential metric (each block only needs to ask it's neighbors to know whether it's on the perimeter), while the former is a factor of the whole subgraph and consequently nine expensive calls nw:mean-path-length calls are needed.

For each measure used, if the swap improves that measure, it is accepted. If the swap degrades the score, we use the following primitive score function to decide whether or not to use the swap:

Take the difference of the old measure and the new measure. Since lower is better, this will be negative for moves that degrade the measure. Multiply the difference by the following scaling factor:

* Population standard deviation: 2
* Perimeter-area ratio: 20
* Mean path length: 2

Add the corresponding leniency factor (set by sliders on the Interface tab). Use this as the mean of a normal distribution with standard deviation 1, then generate a random number with that distribution. If that number is greater than 0, accept the swap; otherwise, reject it.

Note that these functions have no empirical backing beyond my gut feel that they generate vaguely the sort of outcomes we want. It IS important that your score function allows some swaps to make the map worse, because you don't want to get stuck in a local maxima and end up barely exploring map-space. As well, since we start with perfect square subgraphs, the first swap *necessarily* creates a worse map, so the model will get stuck in an infinite loop if your make the score functions too strict. 

If a swap is rejected by even a single measure, throw it away and start over. If a swap is accepted, we update the maps, cache the new district values in each patch within the district, update our statistics and graphs, and then attempt another swap.

## How could it be expanded?

There are two main approaches you could take with this. Whichever one you take, you probably need to change my score functions to something less arbitrary. (If you're looking for them in the code, they're in the latter half of "calculate-impact-of-swap".)

### MCMC

Duke University [has published a paper](https://arxiv.org/pdf/1704.03360.pdf) about their use of MCMC to travel around the space of all maps. But they didn't share their code, so you can't try to tweak conditions and do similar analysis. If you replace my score functions with real-world-relevant ones, and make the maps more realistic, you could have a tool where you could try out similar things. I would be especially interested in trending the proportion of rejected to accepted moves over time, which is why I added a plot for it.

### Metrics as a function of the world

Right now, most people looking at this stuff are traversing the space of all maps, saving off "good maps", then finding average values of them. But is that necessary, or can you derive the average metrics by analyzing the world? (This is analogous to a state in terms of US gerrymandering). If this is ever going to be possible, it's probably going to work for this friendly, square world. 

## Who wrote this?

This was written by Collin Lysford. You can email me at collin.lysford@gmail.com if you have questions, feature requests, or good book recommendations.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.0.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
