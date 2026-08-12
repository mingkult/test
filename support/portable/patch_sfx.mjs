import { rcedit } from 'rcedit';

const [exePath, iconPath, version] = process.argv.slice(2);

if (!exePath || !iconPath || !version) {
  console.error('Usage: node patch_sfx.mjs <sfx.exe> <icon.ico> <version>');
  process.exit(2);
}

await rcedit(exePath, {
  icon: iconPath,
  'file-version': version,
  'product-version': version,
  'requested-execution-level': 'asInvoker',
  'version-string': {
    CompanyName: 'mkLS Open Source Project',
    FileDescription: 'mkLS Portable',
    InternalName: 'mkLS_portable',
    LegalCopyright: 'Based on LocalSend, licensed under Apache-2.0',
    OriginalFilename: 'mkLS.exe',
    ProductName: 'mkLS',
  },
});
