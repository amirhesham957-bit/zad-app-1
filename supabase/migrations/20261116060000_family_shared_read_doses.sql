-- المتابعة بالموافقة كانت بتشوف أدوية العضو (family_shared_read_pharmacy على zad_pharmacy_items) بس
-- مش الجرعات اللي اتاخدت، فالشاشة تقول «الدواء ده بتاعه» من غير ما تقول خدّه ولا لأ. نفس شرط الرؤية بالظبط
-- (zad_family_i_can_see(user_id, 'medicines')) على جدول الجرعات، قراءة بس: الكتابة لصاحب الجرعة وحده.
drop policy if exists family_shared_read_pharmacy_doses on public.zad_pharmacy_doses;
create policy family_shared_read_pharmacy_doses on public.zad_pharmacy_doses
  for select to authenticated
  using (public.zad_family_i_can_see(user_id, 'medicines'));
