for name in ['helpers', 'config', 'model', 'view', 'controller', 'route', 'modoose']
    exports[name] = require("./#{name}.coffee")