let id = x => x
let pipe = (g, f, x) => x->g->f
let compose = (f, g, x) =>  x->g->f