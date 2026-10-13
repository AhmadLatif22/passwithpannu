module.exports = {
  preset: 'ts-jest',
  testEnvironment: 'node',
  roots: ['<rootDir>/src'],
  testMatch: ['**/*.test.ts'],
  globals: { 'ts-jest': { tsconfig: { rootDir: '.', strict: true, esModuleInterop: true, target: 'ES2022', module: 'commonjs' } } },
};
