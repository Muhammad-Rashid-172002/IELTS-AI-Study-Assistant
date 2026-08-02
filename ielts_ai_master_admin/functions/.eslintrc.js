module.exports = {
  root: true,

  env: {
    es6: true,
    node: true,
  },

  parserOptions: {
    ecmaVersion: 2022,
    sourceType: "script",
  },

  extends: [
    "eslint:recommended",
  ],

  rules: {
    "no-unused-vars": [
      "error",
      {
        argsIgnorePattern: "^_",
      },
    ],
    "no-undef": "error",
    "no-console": "off",
    "require-jsdoc": "off",
    "valid-jsdoc": "off",
    "indent": "off",
    "quote-props": "off",
    "max-len": "off",
    "object-curly-spacing": "off",
  },
};
