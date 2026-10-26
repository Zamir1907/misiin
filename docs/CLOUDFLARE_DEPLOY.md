# Cloudflare Pages deployment — tahap 1

1. Push isi folder `misiin` ke GitHub repository.
2. Buka Cloudflare Dashboard > Workers & Pages > Create > Pages > Connect to Git.
3. Pilih repository, framework preset `None`, build command kosong, output directory `.`.
4. Deploy. Uji landing page dan `/api/health`.
5. Atur environment secrets di project settings untuk tahap backend berikutnya; jangan masukkan secrets ke GitHub.
6. Tambahkan domain Pages ke redirect URL Supabase Auth.

Untuk deploy dengan Git integration, root repo harus berisi index.html dan folder functions.
