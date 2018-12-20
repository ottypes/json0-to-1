
const textOpAt = (pos, c) => pos === 0 ? [c] : [pos, c]

const text0ToText = text0Op => (
  text0Op
    .map(c => text.normalize(c.i != null ? [c.p, c.i] : [c.p, {d:c.d.length}]))
    .reduce(text.compose, [])
)

function json0to1(json0Op) {
  // JSON0 ops are a list of {p: path, operation}.
  // See https://github.com/ottypes/json0#summary-of-operations
  return json0Op.map(c => {
    if (c.na != null) return editOp(c.p, 'number', c.na)
    else if (c.li !== undefined && c.ld !== undefined) return replaceOp(c.p, c.ld, c.li)
    else if (c.oi !== undefined && c.od !== undefined) return replaceOp(c.p, c.od, c.oi)
    else if (c.li !== undefined) return insertOp(c.p, c.li)
    else if (c.oi !== undefined) return insertOp(c.p, c.oi)
    else if (c.ld !== undefined) return removeOp(c.p, c.ld)
    else if (c.od !== undefined) return removeOp(c.p, c.od)
    else if (c.t) return c.t === 'text0' ? editOp(c.p, 'text', text0ToText(c.o)) : editOp(c.p, c.t, c.o)
    // Note: Using the old text type here because thats what json0 uses.
    // You will have to register it if you want to use it.
    else if (c.si != null) return editOp(c.p.slice(0, -1), 'text', textOpAt(c.p[c.p.length-1], c.si))
    else if (c.sd != null) return editOp(c.p.slice(0, -1), 'text', textOpAt(c.p[c.p.length-1], {d:c.sd.length}))
    else if (c.lm != null) {
      const p2 = c.p.slice(0, -1)
      p2.push(c.lm)
      return mvOp(c.p, p2)
    }
  }).reduce(compose, null)
}

module.exports = json0to1
