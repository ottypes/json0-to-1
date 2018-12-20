# This is a partial port of the JSON0 tests to run against json1.
# Unfortunately, the transform functions are subtly incompatible. This code
# will be abandoned and moved to a simple genOp randomizer style testing
# suite.

assert = require 'assert'
type = require '../lib/json1'
log = require '../lib/log'
{fromJSON0} = type
type.registerSubtype require 'ot-text'

type.setDebug true

type.registerSubtype
  name: 'mock'
  transform: (a, b, side) ->
    return { mock: true }

# Cross-transform helper function. Transform server by client and client by
# server. Returns [server, client].
transformX = (type, left, right) ->
  [type.transformNoConflict(left, right, 'left'), type.transformNoConflict(right, left, 'right')]


apply = (doc, op, expect) ->
  op_ = fromJSON0 op
  log op_
  result = type.apply doc, op_
  assert.deepStrictEqual result, expect

compose = (op1, op2, expect) ->
  op1_ = fromJSON0 op1
  op2_ = fromJSON0 op2
  expect_ = fromJSON0 expect
  result = type.compose op1_, op2_
  assert.deepStrictEqual result, expect_

# transform = ({op1, op2, expect, expectLeft, expectRight}) ->
#   expectLeft = expectRight = expect if expect?

transform = (op1, op2, side, expect) ->
  op1_ = fromJSON0 op1
  op2_ = fromJSON0 op2
  expect_ = fromJSON0 expect
  result = type.transformNoConflict op1_, op2_, side
  assert.deepStrictEqual result, expect_

xf = ({op1, op2, expect, expectLeft, expectRight}) ->
  expectLeft = expectRight = expect if expect?
  transform op1, op2, 'left', expectLeft
  transform op1, op2, 'right', expectRight

describe 'sanity', ->

  describe '#compose()', ->
    it 'od,oi --> od+oi', ->
      compose [{p:['foo'],od:1}],[{p:['foo'],oi:2}], [{p:['foo'], od:1, oi:2}]
      compose [{p:['foo'],od:1}],[{p:['bar'],oi:2}], [{p:['foo'], od:1},{p:['bar'], oi:2}]
    it 'merges od+oi, od+oi -> od+oi', ->
      compose [{p:['foo'],od:1,oi:3}],[{p:['foo'],od:3,oi:2}], [{p:['foo'], od:1, oi:2}]


  describe '#transform()', -> it 'returns sane values', ->
    t = (op1, op2) ->
      xf {op1, op2, expect: op1}

    t [], []
    t [{p:['foo'], oi:1}], []
    t [{p:['foo'], oi:1}], [{p:['bar'], oi:2}]

describe 'number', ->
  it 'Adds a number', ->
    apply 1, [{p:[], na:2}], 3
    apply [1], [{p:[0], na:2}], [3]

  it 'compresses two adds together in compose', ->
    compose [{p:['a', 'b'], na:1}], [{p:['a', 'b'], na:2}], [{p:['a', 'b'], na:3}]
    compose [{p:['a'], na:1}], [{p:['b'], na:2}], [{p:['a'], na:1}, {p:['b'], na:2}]

  it 'doesn\'t overwrite values when it merges na in append', ->
    rightHas = 21
    leftHas = 3

    rightOp = fromJSON0 [{"p":[],"od":0,"oi":15},{"p":[],"na":4},{"p":[],"na":1},{"p":[],"na":1}]
    leftOp = fromJSON0 [{"p":[],"na":4},{"p":[],"na":-1}]
    [right_, left_] = transformX type, rightOp, leftOp

    s_c = type.apply rightHas, left_
    c_s = type.apply leftHas, right_
    assert.deepEqual s_c, c_s


# Strings should be handled internally by the text type. We'll just do some basic sanity checks here.
describe 'string', ->
  describe '#apply()', -> it 'works', ->
    apply 'a', [{p:[1], si:'bc'}], 'abc'
    apply 'abc', [{p:[0], sd:'a'}], 'bc'
    apply {x:'a'}, [{p:['x', 1], si:'bc'}], {x:'abc'}

  describe '#transform()', ->
    it 'splits deletes', ->
      transform [{p:[0], sd:'ab'}], [{p:[1], si:'x'}], 'left', [{p:[0], sd:'a'}, {p:[1], sd:'b'}]

    it 'cancels out other deletes', ->
      # This has slightly different behaviour - it turns into an empty string query with json1.
      # transform [{p:['k', 5], sd:'a'}], [{p:['k', 5], sd:'a'}], 'left', []
      transform [{p:['k', 5], sd:'a'}], [{p:['k', 5], sd:'a'}], 'left', [p:['k', 5], sd:'']

    it 'does not throw errors with blank inserts', ->
      # transform [{p: ['k', 5], si:''}], [{p: ['k', 3], si: 'a'}], 'left', []
      transform [{p: ['k', 5], si:''}], [{p: ['k', 3], si: 'a'}], 'left', [p:['k', 5], sd:'']

describe 'string subtype', ->
  describe '#apply()', ->
    it 'works', ->
      apply 'a', [{p:[], t:'text0', o:[{p:1, i:'bc'}]}], 'abc'
      apply 'abc', [{p:[], t:'text0', o:[{p:0, d:'a'}]}], 'bc'
      apply {x:'a'}, [{p:['x'], t:'text0', o:[{p:1, i:'bc'}]}], {x:'abc'}

  describe '#transform()', ->
    it 'splits deletes', ->
      a = [{p:[], t:'text0', o:[{p:0, d:'ab'}]}]
      b = [{p:[], t:'text0', o:[{p:1, i:'x'}]}]
      transform a, b, 'left', [{p:[], t:'text0', o:[{p:0, d:'a'}, {p:1, d:'b'}]}]

    it 'cancels out other deletes', ->
      # With json0 we get an empty op instead of a noop
      # transform [{p:['k'], t:'text0', o:[{p:5, d:'a'}]}], [{p:['k'], t:'text0', o:[{p:5, d:'a'}]}], 'left', []
      transform [{p:['k'], t:'text0', o:[{p:5, d:'a'}]}], [{p:['k'], t:'text0', o:[{p:5, d:'a'}]}], 'left', [{p:['k'], t:'text0', o:[]}]

    it 'does not throw errors with blank inserts', ->
      # transform [{p:['k'], t:'text0', o:[{p:5, i:''}]}], [{p:['k'], t:'text0', o:[{p:3, i:'a'}]}], 'left', []
      transform [{p:['k'], t:'text0', o:[{p:5, i:''}]}], [{p:['k'], t:'text0', o:[{p:3, i:'a'}]}], 'left', [{p:['k'], t:'text0', o:[]}]

describe 'subtype with non-array operation', ->
  describe '#transform()', ->
    it 'works', ->
      a = [{p:[], t:'mock', o:'foo'}]
      b = [{p:[], t:'mock', o:'bar'}]
      transform a, b, 'left', [{p:[], t:'mock', o:{mock:true}}]

describe 'list', ->
  describe 'apply', ->
    it 'inserts', ->
      apply ['b', 'c'], [{p:[0], li:'a'}], ['a', 'b', 'c']
      apply ['a', 'c'], [{p:[1], li:'b'}], ['a', 'b', 'c']
      apply ['a', 'b'], [{p:[2], li:'c'}], ['a', 'b', 'c']

    it 'deletes', ->
      apply ['a', 'b', 'c'], [{p:[0], ld:'a'}], ['b', 'c']
      apply ['a', 'b', 'c'], [{p:[1], ld:'b'}], ['a', 'c']
      apply ['a', 'b', 'c'], [{p:[2], ld:'c'}], ['a', 'b']

    it 'replaces', ->
      apply ['a', 'x', 'b'], [{p:[1], ld:'x', li:'y'}], ['a', 'y', 'b']

    it 'moves', ->
      apply ['b', 'a', 'c'], [{p:[1], lm:0}], ['a', 'b', 'c']
      apply ['b', 'a', 'c'], [{p:[0], lm:1}], ['a', 'b', 'c']

    ###
    'null moves compose to nops', ->
      assert.deepEqual [], type.compose [], [{p:[3],lm:3}]
      assert.deepEqual [], type.compose [], [{p:[0,3],lm:3}]
      assert.deepEqual [], type.compose [], [{p:['x','y',0],lm:0}]
    ###

  describe '#transform()', ->
    it 'bumps paths when list elements are inserted or removed', ->
      transform [{p:[1, 200], si:'hi'}], [{p:[0], li:'x'}], 'left', [{p:[2, 200], si:'hi'}]
      transform [{p:[0, 201], si:'hi'}], [{p:[0], li:'x'}], 'right', [{p:[1, 201], si:'hi'}]
      transform [{p:[0, 202], si:'hi'}], [{p:[1], li:'x'}], 'left', [{p:[0, 202], si:'hi'}]
      transform [{p:[1], t:'text0', o:[{p:200, i:'hi'}]}], [{p:[0], li:'x'}], 'left', [{p:[2], t:'text0', o:[{p:200, i:'hi'}]}]
      transform [{p:[0], t:'text0', o:[{p:201, i:'hi'}]}], [{p:[0], li:'x'}], 'right', [{p:[1], t:'text0', o:[{p:201, i:'hi'}]}]
      transform [{p:[0], t:'text0', o:[{p:202, i:'hi'}]}], [{p:[1], li:'x'}], 'left', [{p:[0], t:'text0', o:[{p:202, i:'hi'}]}]

      transform [{p:[1, 203], si:'hi'}], [{p:[0], ld:'x'}], 'left', [{p:[0, 203], si:'hi'}]
      transform [{p:[0, 204], si:'hi'}], [{p:[1], ld:'x'}], 'left', [{p:[0, 204], si:'hi'}]
      transform [{p:['x',3], si:'hi'}], [{p:['x',0,'x'], li:0}], 'left', [{p:['x',3], si: 'hi'}]
      transform [{p:['x',3,'x'], si:'hi'}], [{p:['x',5], li:0}], 'left', [{p:['x',3,'x'], si: 'hi'}]
      transform [{p:['x',3,'x'], si:'hi'}], [{p:['x',0], li:0}], 'left', [{p:['x',4,'x'], si: 'hi'}]
      transform [{p:[1], t:'text0', o:[{p:203, i:'hi'}]}], [{p:[0], ld:'x'}], 'left', [{p:[0], t:'text0', o:[{p:203, i:'hi'}]}]
      transform [{p:[0], t:'text0', o:[{p:204, i:'hi'}]}], [{p:[1], ld:'x'}], 'left', [{p:[0], t:'text0', o:[{p:204, i:'hi'}]}]
      transform [{p:['x'], t:'text0', o:[{p:3, i:'hi'}]}], [{p:['x',0,'x'], li:0}], 'left', [{p:['x'], t:'text0', o:[{p:3,i: 'hi'}]}]

      # json1 does not preserve remove information
      # transform [{p:[0],ld:2}], [{p:[0],li:1}], 'left', [{p:[1],ld:2}]
      # transform [{p:[0],ld:2}], [{p:[0],li:1}], 'right', [{p:[1],ld:2}]
      transform [{p:[0],ld:2}], [{p:[0],li:1}], 'left', [{p:[1],ld:true}]
      transform [{p:[0],ld:2}], [{p:[0],li:1}], 'right', [{p:[1],ld:true}]

    it 'converts ops on deleted elements to noops', ->
      transform [{p:[1, 0], si:'hi'}], [{p:[1], ld:'x'}], 'left', []
      transform [{p:[1], t:'text0', o:[{p:0, i:'hi'}]}], [{p:[1], ld:'x'}], 'left', []
      transform [{p:[0],li:'x'}], [{p:[0],ld:'y'}], 'left', [{p:[0],li:'x'}]
      transform [{p:[0],na:-3}], [{p:[0],ld:48}], 'left', []

    it 'converts ops on replaced elements to noops', ->
      transform [{p:[1, 0], si:'hi'}], [{p:[1], ld:'x', li:'y'}], 'left', []
      transform [{p:[1], t:'text0', o:[{p:0, i:'hi'}]}], [{p:[1], ld:'x', li:'y'}], 'left', []
      transform [{p:[0], li:'hi'}], [{p:[0], ld:'x', li:'y'}], 'left', [{p:[0], li:'hi'}]

    it 'changes deleted data to reflect edits', ->
      # transform [{p:[1], ld:'a'}], [{p:[1, 1], si:'bc'}], 'left', [{p:[1], ld:'abc'}]
      # transform [{p:[1], ld:'a'}], [{p:[1], t:'text0', o:[{p:1, i:'bc'}]}], 'left', [{p:[1], ld:'abc'}]
      transform [{p:[1], ld:'a'}], [{p:[1, 1], si:'bc'}], 'left', [{p:[1], ld:true}]
      transform [{p:[1], ld:'a'}], [{p:[1], t:'text0', o:[{p:1, i:'bc'}]}], 'left', [{p:[1], ld:true}]

    it 'Puts the left op first if two inserts are simultaneous', ->
      transform [{p:[1], li:'a'}], [{p:[1], li:'b'}], 'left', [{p:[1], li:'a'}]
      transform [{p:[1], li:'b'}], [{p:[1], li:'a'}], 'right', [{p:[2], li:'b'}]

    it 'converts an attempt to re-delete a list element into a no-op', ->
      transform [{p:[1], ld:'x'}], [{p:[1], ld:'x'}], 'left', []
      transform [{p:[1], ld:'x'}], [{p:[1], ld:'x'}], 'right', []


  describe '#compose()', ->
    it 'composes insert then delete into a no-op', ->
      compose [{p:[1], li:'abc'}], [{p:[1], ld:'abc'}], []
      # transform [{p:[0],ld:null,li:"x"}], [{p:[0],li:"The"}], 'right', [{p:[1],ld:null,li:'x'}]
      transform [{p:[0],ld:null,li:"x"}], [{p:[0],li:"The"}], 'right', [{p:[1],ld:true,li:'x'}]

    it 'doesn\'t change the original object', ->
      a = fromJSON0 [{p:[0],ld:'abc',li:null}]
      a_orig = JSON.parse JSON.stringify a
      assert.deepEqual fromJSON0([{p:[0],ld:'abc'}]), type.compose a, fromJSON0([{p:[0],ld:null}])
      assert.deepEqual a, a_orig

    it 'composes together adjacent string ops', ->
      compose [{p:[100], si:'h'}], [{p:[101], si:'i'}], [{p:[100], si:'hi'}]
      compose [{p:[], t:'text0', o:[{p:100, i:'h'}]}], [{p:[], t:'text0', o:[{p:101, i:'i'}]}], [{p:[], t:'text0', o:[{p:100, i:'hi'}]}]

  it 'moves ops on a moved element with the element', ->
    # transform [{p:[4], ld:'x'}], [{p:[4], lm:10}], 'left', [{p:[10], ld:'x'}]
    transform [{p:[4], ld:'x'}], [{p:[4], lm:10}], 'left', [{p:[10], ld:true}]
    transform [{p:[4, 1], si:'a'}], [{p:[4], lm:10}], 'left', [{p:[10, 1], si:'a'}]
    transform [{p:[4], t:'text0', o:[{p:1, i:'a'}]}], [{p:[4], lm:10}], 'left', [{p:[10], t:'text0', o:[{p:1, i:'a'}]}]
    transform [{p:[4, 1], li:'a'}], [{p:[4], lm:10}], 'left', [{p:[10, 1], li:'a'}]
    # transform [{p:[4, 1], ld:'b', li:'a'}], [{p:[4], lm:10}], 'left', [{p:[10, 1], ld:'b', li:'a'}]
    transform [{p:[4, 1], ld:'b', li:'a'}], [{p:[4], lm:10}], 'left', [{p:[10, 1], ld:true, li:'a'}]

    transform [{p:[0],li:null}], [{p:[0],lm:1}], 'left', [{p:[0],li:null}]
    # [_,_,_,_,5,6,7,_]
    # c: [_,_,_,_,5,'x',6,7,_]   p:5 li:'x'
    # s: [_,6,_,_,_,5,7,_]       p:5 lm:1
    # correct: [_,6,_,_,_,5,'x',7,_]
    transform [{p:[5],li:'x'}], [{p:[5],lm:1}], 'left', [{p:[6],li:'x'}]
    # [_,_,_,_,5,6,7,_]
    # c: [_,_,_,_,5,6,7,_]  p:5 ld:6
    # s: [_,6,_,_,_,5,7,_]  p:5 lm:1
    # correct: [_,_,_,_,5,7,_]
    # transform [{p:[5],ld:6}], [{p:[5],lm:1}], 'left', [{p:[1],ld:6}]
    transform [{p:[5],ld:6}], [{p:[5],lm:1}], 'left', [{p:[1],ld:true}]
    #assert.deepEqual [{p:[0],li:{}}], type.transform [{p:[0],li:{}}], [{p:[0],lm:0}], 'right'
    transform [{p:[0],li:[]}], [{p:[1],lm:0}], 'left', [{p:[0],li:[]}]

  it.only 'xxx', ->
    transform [{p:[2],li:'x'}], [{p:[0],lm:1}], 'left', [{p:[2],li:'x'}]

  it 'moves target index on ld/li', ->
    transform [{p:[0], lm: 2}], [{p:[1], ld:'x'}], 'left', [{p:[0],lm:1}]
    transform [{p:[2], lm: 4}], [{p:[1], ld:'x'}], 'left', [{p:[1],lm:3}]
    transform [{p:[0], lm: 2}], [{p:[1], li:'x'}], 'left', [{p:[0],lm:3}]
    transform [{p:[2], lm: 4}], [{p:[1], li:'x'}], 'left', [{p:[3],lm:5}]
    transform [{p:[0], lm: 0}], [{p:[0], li:28}], 'left', [{p:[1],lm:1}]

  it 'tiebreaks lm vs. ld/li', ->
    transform [{p:[0], lm: 2}], [{p:[0], ld:'x'}], 'left', []
    transform [{p:[0], lm: 2}], [{p:[0], ld:'x'}], 'right', []
    transform [{p:[0], lm: 2}], [{p:[0], li:'x'}], 'left', [{p:[1], lm:3}]
    transform [{p:[0], lm: 2}], [{p:[0], li:'x'}], 'right', [{p:[1], lm:3}]

  it 'replacement vs. deletion', ->
    transform [{p:[0],ld:'x',li:'y'}], [{p:[0],ld:'x'}], 'right', [{p:[0],li:'y'}]

  it 'replacement vs. insertion', ->
    transform [{p:[0],ld:{},li:"brillig"}], [{p:[0],li:36}], 'left', [{p:[1],ld:{},li:"brillig"}]

  it 'replacement vs. replacement', ->
    transform [{p:[0],ld:null,li:[]}], [{p:[0],ld:null,li:0}], 'right', []
    transform [{p:[0],ld:null,li:0}], [{p:[0],ld:null,li:[]}], 'left', [{p:[0],ld:[],li:0}]

  it 'composes replace with delete of replaced element results in insert', ->
    assert.deepEqual [{p:[2],ld:[]}], type.compose [{p:[2],ld:[],li:null}], [{p:[2],ld:null}]

  it 'lm vs lm', ->
    assert.deepEqual [{p:[0],lm:2}], type.transform [{p:[0],lm:2}], [{p:[2],lm:1}], 'left'
    assert.deepEqual [{p:[4],lm:4}], type.transform [{p:[3],lm:3}], [{p:[5],lm:0}], 'left'
    assert.deepEqual [{p:[2],lm:0}], type.transform [{p:[2],lm:0}], [{p:[1],lm:0}], 'left'
    assert.deepEqual [{p:[2],lm:1}], type.transform [{p:[2],lm:0}], [{p:[1],lm:0}], 'right'
    assert.deepEqual [{p:[3],lm:1}], type.transform [{p:[2],lm:0}], [{p:[5],lm:0}], 'right'
    assert.deepEqual [{p:[3],lm:0}], type.transform [{p:[2],lm:0}], [{p:[5],lm:0}], 'left'
    assert.deepEqual [{p:[0],lm:5}], type.transform [{p:[2],lm:5}], [{p:[2],lm:0}], 'left'
    assert.deepEqual [{p:[0],lm:5}], type.transform [{p:[2],lm:5}], [{p:[2],lm:0}], 'left'
    assert.deepEqual [{p:[0],lm:0}], type.transform [{p:[1],lm:0}], [{p:[0],lm:5}], 'right'
    assert.deepEqual [{p:[0],lm:0}], type.transform [{p:[1],lm:0}], [{p:[0],lm:1}], 'right'
    assert.deepEqual [{p:[1],lm:1}], type.transform [{p:[0],lm:1}], [{p:[1],lm:0}], 'left'
    assert.deepEqual [{p:[1],lm:2}], type.transform [{p:[0],lm:1}], [{p:[5],lm:0}], 'right'
    assert.deepEqual [{p:[3],lm:2}], type.transform [{p:[2],lm:1}], [{p:[5],lm:0}], 'right'
    assert.deepEqual [{p:[2],lm:1}], type.transform [{p:[3],lm:1}], [{p:[1],lm:3}], 'left'
    assert.deepEqual [{p:[2],lm:3}], type.transform [{p:[1],lm:3}], [{p:[3],lm:1}], 'left'
    assert.deepEqual [{p:[2],lm:6}], type.transform [{p:[2],lm:6}], [{p:[0],lm:1}], 'left'
    assert.deepEqual [{p:[2],lm:6}], type.transform [{p:[2],lm:6}], [{p:[0],lm:1}], 'right'
    assert.deepEqual [{p:[2],lm:6}], type.transform [{p:[2],lm:6}], [{p:[1],lm:0}], 'left'
    assert.deepEqual [{p:[2],lm:6}], type.transform [{p:[2],lm:6}], [{p:[1],lm:0}], 'right'
    assert.deepEqual [{p:[0],lm:2}], type.transform [{p:[0],lm:1}], [{p:[2],lm:1}], 'left'
    assert.deepEqual [{p:[2],lm:0}], type.transform [{p:[2],lm:1}], [{p:[0],lm:1}], 'right'
    assert.deepEqual [{p:[1],lm:1}], type.transform [{p:[0],lm:0}], [{p:[1],lm:0}], 'left'
    assert.deepEqual [{p:[0],lm:0}], type.transform [{p:[0],lm:1}], [{p:[1],lm:3}], 'left'
    assert.deepEqual [{p:[3],lm:1}], type.transform [{p:[2],lm:1}], [{p:[3],lm:2}], 'left'
    assert.deepEqual [{p:[3],lm:3}], type.transform [{p:[3],lm:2}], [{p:[2],lm:1}], 'left'

  it 'changes indices correctly around a move', ->
    assert.deepEqual [{p:[1,0],li:{}}], type.transform [{p:[0,0],li:{}}], [{p:[1],lm:0}], 'left'
    assert.deepEqual [{p:[0],lm:0}], type.transform [{p:[1],lm:0}], [{p:[0],ld:{}}], 'left'
    assert.deepEqual [{p:[0],lm:0}], type.transform [{p:[0],lm:1}], [{p:[1],ld:{}}], 'left'
    assert.deepEqual [{p:[5],lm:0}], type.transform [{p:[6],lm:0}], [{p:[2],ld:{}}], 'left'
    assert.deepEqual [{p:[1],lm:0}], type.transform [{p:[1],lm:0}], [{p:[2],ld:{}}], 'left'
    assert.deepEqual [{p:[1],lm:1}], type.transform [{p:[2],lm:1}], [{p:[1],ld:3}], 'right'

    assert.deepEqual [{p:[1],ld:{}}], type.transform [{p:[2],ld:{}}], [{p:[1],lm:2}], 'right'
    assert.deepEqual [{p:[2],ld:{}}], type.transform [{p:[1],ld:{}}], [{p:[2],lm:1}], 'left'


    assert.deepEqual [{p:[0],ld:{}}], type.transform [{p:[1],ld:{}}], [{p:[0],lm:1}], 'right'

    assert.deepEqual [{p:[0],ld:1,li:2}], type.transform [{p:[1],ld:1,li:2}], [{p:[1],lm:0}], 'left'
    assert.deepEqual [{p:[0],ld:2,li:3}], type.transform [{p:[1],ld:2,li:3}], [{p:[0],lm:1}], 'left'
    assert.deepEqual [{p:[1],ld:3,li:4}], type.transform [{p:[0],ld:3,li:4}], [{p:[1],lm:0}], 'left'

  it 'li vs lm', ->
    li = (p) -> [{p:[p],li:[]}]
    lm = (f,t) -> [{p:[f],lm:t}]
    xf = type.transform

    assert.deepEqual (li 0), xf (li 0), (lm 1, 3), 'left'
    assert.deepEqual (li 1), xf (li 1), (lm 1, 3), 'left'
    assert.deepEqual (li 1), xf (li 2), (lm 1, 3), 'left'
    assert.deepEqual (li 2), xf (li 3), (lm 1, 3), 'left'
    assert.deepEqual (li 4), xf (li 4), (lm 1, 3), 'left'

    assert.deepEqual (lm 2, 4), xf (lm 1, 3), (li 0), 'right'
    assert.deepEqual (lm 2, 4), xf (lm 1, 3), (li 1), 'right'
    assert.deepEqual (lm 1, 4), xf (lm 1, 3), (li 2), 'right'
    assert.deepEqual (lm 1, 4), xf (lm 1, 3), (li 3), 'right'
    assert.deepEqual (lm 1, 3), xf (lm 1, 3), (li 4), 'right'

    assert.deepEqual (li 0), xf (li 0), (lm 1, 2), 'left'
    assert.deepEqual (li 1), xf (li 1), (lm 1, 2), 'left'
    assert.deepEqual (li 1), xf (li 2), (lm 1, 2), 'left'
    assert.deepEqual (li 3), xf (li 3), (lm 1, 2), 'left'

    assert.deepEqual (li 0), xf (li 0), (lm 3, 1), 'left'
    assert.deepEqual (li 1), xf (li 1), (lm 3, 1), 'left'
    assert.deepEqual (li 3), xf (li 2), (lm 3, 1), 'left'
    assert.deepEqual (li 4), xf (li 3), (lm 3, 1), 'left'
    assert.deepEqual (li 4), xf (li 4), (lm 3, 1), 'left'

    assert.deepEqual (lm 4, 2), xf (lm 3, 1), (li 0), 'right'
    assert.deepEqual (lm 4, 2), xf (lm 3, 1), (li 1), 'right'
    assert.deepEqual (lm 4, 1), xf (lm 3, 1), (li 2), 'right'
    assert.deepEqual (lm 4, 1), xf (lm 3, 1), (li 3), 'right'
    assert.deepEqual (lm 3, 1), xf (lm 3, 1), (li 4), 'right'

    assert.deepEqual (li 0), xf (li 0), (lm 2, 1), 'left'
    assert.deepEqual (li 1), xf (li 1), (lm 2, 1), 'left'
    assert.deepEqual (li 3), xf (li 2), (lm 2, 1), 'left'
    assert.deepEqual (li 3), xf (li 3), (lm 2, 1), 'left'


describe 'object', ->
  it 'passes sanity checks', ->
    assert.deepEqual {x:'a', y:'b'}, type.apply {x:'a'}, [{p:['y'], oi:'b'}]
    assert.deepEqual {}, type.apply {x:'a'}, [{p:['x'], od:'a'}]
    assert.deepEqual {x:'b'}, type.apply {x:'a'}, [{p:['x'], od:'a', oi:'b'}]

  it 'Ops on deleted elements become noops', ->
    assert.deepEqual [], type.transform [{p:[1, 0], si:'hi'}], [{p:[1], od:'x'}], 'left'
    assert.deepEqual [], type.transform [{p:[1], t:'text0', o:[{p:0, i:'hi'}]}], [{p:[1], od:'x'}], 'left'
    assert.deepEqual [], type.transform [{p:[9],si:"bite "}], [{p:[],od:"agimble s",oi:null}], 'right'
    assert.deepEqual [], type.transform [{p:[], t:'text0', o:[{p:9, i:"bite "}]}], [{p:[],od:"agimble s",oi:null}], 'right'

  it 'Ops on replaced elements become noops', ->
    assert.deepEqual [], type.transform [{p:[1, 0], si:'hi'}], [{p:[1], od:'x', oi:'y'}], 'left'
    assert.deepEqual [], type.transform [{p:[1], t:'text0', o:[{p:0, i:'hi'}]}], [{p:[1], od:'x', oi:'y'}], 'left'

  it 'Deleted data is changed to reflect edits', ->
    assert.deepEqual [{p:[1], od:'abc'}], type.transform [{p:[1], od:'a'}], [{p:[1, 1], si:'bc'}], 'left'
    assert.deepEqual [{p:[1], od:'abc'}], type.transform [{p:[1], od:'a'}], [{p:[1], t:'text0', o:[{p:1, i:'bc'}]}], 'left'
    assert.deepEqual [{p:[],od:25,oi:[]}], type.transform [{p:[],od:22,oi:[]}], [{p:[],na:3}], 'left'
    assert.deepEqual [{p:[],od:{toves:""},oi:4}], type.transform [{p:[],od:{toves:0},oi:4}], [{p:["toves"],od:0,oi:""}], 'left'
    assert.deepEqual [{p:[],od:"thou an",oi:[]}], type.transform [{p:[],od:"thou and ",oi:[]}], [{p:[7],sd:"d "}], 'left'
    assert.deepEqual [{p:[],od:"thou an",oi:[]}], type.transform [{p:[],od:"thou and ",oi:[]}], [{p:[], t:'text0', o:[{p:7, d:"d "}]}], 'left'
    assert.deepEqual [], type.transform([{p:["bird"],na:2}], [{p:[],od:{bird:38},oi:20}], 'right')
    assert.deepEqual [{p:[],od:{bird:40},oi:20}], type.transform([{p:[],od:{bird:38},oi:20}], [{p:["bird"],na:2}], 'left')
    assert.deepEqual [{p:['He'],od:[]}], type.transform [{p:["He"],od:[]}], [{p:["The"],na:-3}], 'right'
    assert.deepEqual [], type.transform [{p:["He"],oi:{}}], [{p:[],od:{},oi:"the"}], 'left'

  it 'If two inserts are simultaneous, the lefts insert will win', ->
    assert.deepEqual [{p:[1], oi:'a', od:'b'}], type.transform [{p:[1], oi:'a'}], [{p:[1], oi:'b'}], 'left'
    assert.deepEqual [], type.transform [{p:[1], oi:'b'}], [{p:[1], oi:'a'}], 'right'

  it 'parallel ops on different keys miss each other', ->
    assert.deepEqual [{p:['a'], oi: 'x'}], type.transform [{p:['a'], oi:'x'}], [{p:['b'], oi:'z'}], 'left'
    assert.deepEqual [{p:['a'], oi: 'x'}], type.transform [{p:['a'], oi:'x'}], [{p:['b'], od:'z'}], 'left'
    assert.deepEqual [{p:["in","he"],oi:{}}], type.transform [{p:["in","he"],oi:{}}], [{p:["and"],od:{}}], 'right'
    assert.deepEqual [{p:['x',0],si:"his "}], type.transform [{p:['x',0],si:"his "}], [{p:['y'],od:0,oi:1}], 'right'
    assert.deepEqual [{p:['x'], t:'text0', o:[{p:0, i:"his "}]}], type.transform [{p:['x'],t:'text0', o:[{p:0, i:"his "}]}], [{p:['y'],od:0,oi:1}], 'right'

  it 'replacement vs. deletion', ->
    assert.deepEqual [{p:[],oi:{}}], type.transform [{p:[],od:[''],oi:{}}], [{p:[],od:['']}], 'right'

  it 'replacement vs. replacement', ->
    assert.deepEqual [],                     type.transform [{p:[],od:['']},{p:[],oi:{}}], [{p:[],od:['']},{p:[],oi:null}], 'right'
    assert.deepEqual [{p:[],od:null,oi:{}}], type.transform [{p:[],od:['']},{p:[],oi:{}}], [{p:[],od:['']},{p:[],oi:null}], 'left'
    assert.deepEqual [],                     type.transform [{p:[],od:[''],oi:{}}], [{p:[],od:[''],oi:null}], 'right'
    assert.deepEqual [{p:[],od:null,oi:{}}], type.transform [{p:[],od:[''],oi:{}}], [{p:[],od:[''],oi:null}], 'left'

    # test diamond property
    rightOps = [ {"p":[],"od":null,"oi":{}} ]
    leftOps = [ {"p":[],"od":null,"oi":""} ]
    rightHas = type.apply(null, rightOps)
    leftHas = type.apply(null, leftOps)

    [left_, right_] = transformX type, leftOps, rightOps
    assert.deepEqual leftHas, type.apply rightHas, left_
    assert.deepEqual leftHas, type.apply leftHas, right_


  it 'An attempt to re-delete a key becomes a no-op', ->
    assert.deepEqual [], type.transform [{p:['k'], od:'x'}], [{p:['k'], od:'x'}], 'left'
    assert.deepEqual [], type.transform [{p:['k'], od:'x'}], [{p:['k'], od:'x'}], 'right'
