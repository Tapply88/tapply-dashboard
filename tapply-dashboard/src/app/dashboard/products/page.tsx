'use client';

import { useEffect, useState, useCallback } from 'react';
import { createClient } from '@/lib/supabase/client';

type Product = {
  id: string;
  name: string;
  price: number;
  category: string;
  stock: number;
  is_active: boolean;
};

function formatRupiah(amount: number) {
  return new Intl.NumberFormat('id-ID', { style: 'currency', currency: 'IDR', maximumFractionDigits: 0 }).format(amount);
}

export default function ProductsPage() {
  const supabase = createClient();
  const [products, setProducts] = useState<Product[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [editing, setEditing] = useState<Product | null>(null);
  const [form, setForm] = useState({ name: '', price: '', category: 'Umum', stock: '0' });

  const loadProducts = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase.from('products').select('*').order('name');
    setProducts(data ?? []);
    setLoading(false);
  }, [supabase]);

  useEffect(() => {
    loadProducts();
  }, [loadProducts]);

  function openAddForm() {
    setEditing(null);
    setForm({ name: '', price: '', category: 'Umum', stock: '0' });
    setShowForm(true);
  }

  function openEditForm(p: Product) {
    setEditing(p);
    setForm({ name: p.name, price: String(p.price), category: p.category, stock: String(p.stock) });
    setShowForm(true);
  }

  async function handleSave(e: React.FormEvent) {
    e.preventDefault();
    const payload = {
      name: form.name.trim(),
      price: Number(form.price) || 0,
      category: form.category.trim() || 'Umum',
      stock: Number(form.stock) || 0,
    };
    if (!payload.name) return;

    if (editing) {
      await supabase.from('products').update(payload).eq('id', editing.id);
    } else {
      await supabase.from('products').insert(payload);
    }
    setShowForm(false);
    loadProducts();
  }

  async function handleDelete(id: string) {
    if (!confirm('Hapus produk ini?')) return;
    await supabase.from('products').delete().eq('id', id);
    loadProducts();
  }

  return (
    <div>
      <div className="flex items-center justify-between mb-8">
        <div>
          <p className="label-eyebrow mb-2">Katalog</p>
          <h1 className="text-2xl font-semibold">Produk</h1>
        </div>
        <button
          onClick={openAddForm}
          className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium hover:bg-navy-soft transition-colors"
        >
          + Tambah Produk
        </button>
      </div>

      {showForm && (
        <form onSubmit={handleSave} className="receipt-card max-w-lg mb-8 flex flex-col gap-4">
          <p className="label-eyebrow">{editing ? 'Edit Produk' : 'Produk Baru'}</p>
          <input
            required
            value={form.name}
            onChange={(e) => setForm({ ...form, name: e.target.value })}
            placeholder="Nama produk"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <div className="grid grid-cols-2 gap-3">
            <input
              required
              type="number"
              value={form.price}
              onChange={(e) => setForm({ ...form, price: e.target.value })}
              placeholder="Harga (Rp)"
              className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
            <input
              type="number"
              value={form.stock}
              onChange={(e) => setForm({ ...form, stock: e.target.value })}
              placeholder="Stok"
              className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
            />
          </div>
          <input
            value={form.category}
            onChange={(e) => setForm({ ...form, category: e.target.value })}
            placeholder="Kategori"
            className="rounded-lg border border-grey px-4 py-2.5 focus:border-navy outline-none"
          />
          <div className="flex gap-3">
            <button type="submit" className="rounded-full bg-navy text-white px-5 py-2.5 text-sm font-medium">
              Simpan
            </button>
            <button
              type="button"
              onClick={() => setShowForm(false)}
              className="rounded-full border border-grey px-5 py-2.5 text-sm font-medium"
            >
              Batal
            </button>
          </div>
        </form>
      )}

      {loading ? (
        <p className="text-sm text-ink/50">Memuat...</p>
      ) : products.length === 0 ? (
        <div className="receipt-card max-w-lg text-center py-10">
          <p className="text-ink/60">Belum ada produk. Tambahin dulu produk pertama kamu.</p>
        </div>
      ) : (
        <div className="receipt-card overflow-hidden !p-0">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-grey-light text-left">
                <th className="label-eyebrow px-5 py-3 font-medium">Nama</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Kategori</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Harga</th>
                <th className="label-eyebrow px-5 py-3 font-medium">Stok</th>
                <th className="px-5 py-3"></th>
              </tr>
            </thead>
            <tbody>
              {products.map((p) => (
                <tr key={p.id} className="border-b border-grey-light last:border-0">
                  <td className="px-5 py-3 font-medium">{p.name}</td>
                  <td className="px-5 py-3 text-ink/60">{p.category}</td>
                  <td className="px-5 py-3 figure">{formatRupiah(p.price)}</td>
                  <td className="px-5 py-3">
                    <span className={p.stock <= 5 ? 'text-rust font-medium' : ''}>{p.stock}</span>
                  </td>
                  <td className="px-5 py-3 text-right">
                    <button onClick={() => openEditForm(p)} className="text-navy text-xs font-medium mr-3">
                      Edit
                    </button>
                    <button onClick={() => handleDelete(p.id)} className="text-rust text-xs font-medium">
                      Hapus
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
