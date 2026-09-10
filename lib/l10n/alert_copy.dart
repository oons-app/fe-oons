/// In-app alert copy. Keep in sync with server/internal/notify/alerts.go.
class AlertCopy {
  static (String title, String body) of(
    String type, {
    required String lang,
    required String party,
    String? fallbackTitle,
    String? fallbackBody,
  }) {
    final table = lang == 'en' ? _en : _ar;
    final pair = table['$type.$party'] ?? table[type] ?? table['default']!;
    var title = pair.$1;
    var body = pair.$2;
    if (title.isEmpty) title = fallbackTitle ?? '';
    if (body.isEmpty) body = fallbackBody ?? '';
    final ref = bookingRef(fallbackBody ?? '');
    if (ref.isNotEmpty && !body.contains(ref)) body = '$body · $ref';
    return (title, body);
  }

  static String bookingRef(String body) {
    const mark = ' · ';
    final i = body.lastIndexOf(mark);
    if (i < 0) return '';
    final tail = body.substring(i + mark.length);
    return tail.startsWith('ONS-') ? tail : '';
  }
}

const _ar = <String, (String, String)>{
  'default': ('أنس', 'في تحديث على زيارة.'),
  'paid': ('حجز جديد', 'عميلة دفعت. شوفي تفاصيل الزيارة.'),
  'paid.client': ('اتدفع', 'حجزك اتأكد. هتوصّلك تفاصيل الزيارة.'),
  'paid.provider': ('حجز جديد', 'عميلة دفعت. شوفي تفاصيل الزيارة.'),
  'pending_payment.client': ('مستنية دفع', 'لسه في مبلغ مستني على الحجز.'),
  'pending_payment.provider': ('مستنية دفع', 'الحجز لسه مستني دفع العميلة.'),
  'on_the_way': ('في الطريق', 'المتخصصة في الطريق ليكي.'),
  'on_the_way.client': ('في الطريق', 'المتخصصة في الطريق ليكي.'),
  'on_the_way.provider': ('في الطريق', 'العميلة عارفة إنكِ في الطريق.'),
  'at_door': ('عند الباب', 'المتخصصة وصلت. أكّدي لو لسه مأكدتيش.'),
  'at_door.client': ('عند الباب', 'المتخصصة وصلت. أكّدي لو لسه مأكدتيش.'),
  'at_door.provider': ('عند الباب', 'العميلة هتأكد إنكِ وصلتي.'),
  'in_progress': ('الزيارة بدأت', 'الزيارة شغالة دلوقتي.'),
  'in_progress.client': ('الزيارة بدأت', 'الزيارة شغالة دلوقتي.'),
  'in_progress.provider': ('الزيارة بدأت', 'العميلة أكّدت. الزيارة شغالة.'),
  'completed': ('خلصت الزيارة', 'الزيارة اتقفلت.'),
  'completed.client': ('خلصت الزيارة', 'تقدري تقيّمي المتخصصة.'),
  'completed.provider': ('خلصت الزيارة', 'الزيارة اتقفلت. فلوسك هتتراجع بعد يومين.'),
  'cancelled_provider': ('إلغاء', 'المتخصصة لغت. في بديل بنفس الموعد لو حابة.'),
  'cancelled_provider.client': ('إلغاء', 'المتخصصة لغت. في بديل بنفس الموعد لو حابة.'),
  'cancelled_provider.provider': ('إلغاء', 'الحجز اتلغى من طرفكِ.'),
  'cancelled_client': ('إلغاء', 'العميلة لغت الزيارة.'),
  'cancelled_client.client': ('إلغاء', 'حجزكِ اتلغى.'),
  'cancelled_client.provider': ('إلغاء', 'العميلة لغت الزيارة.'),
  'dispute': ('نزاع', 'اتفتح نزاع على زيارة. راجعي التفاصيل.'),
  'dispute.client': ('نزاع', 'النزاع اتسجل. الفلوس واقفة لحد ما نراجع.'),
  'dispute.provider': ('نزاع', 'اتفتح نزاع على زيارة. راجعي التفاصيل.'),
  'disputed.client': ('نزاع', 'النزاع اتسجل. الفلوس واقفة لحد ما نراجع.'),
  'disputed.provider': ('نزاع', 'اتفتح نزاع على زيارة. راجعي التفاصيل.'),
  'dispute_refund.client': ('استرداد', 'النزاع اتقفل. المبلغ هيرجع للطريقة اللي دفعتي بيها.'),
  'dispute_refund.provider': ('استرداد', 'النزاع اتقفل بالاسترداد. مفيش صرف على الزيارة دي.'),
  'dispute_release.client': ('اتقفلت', 'النزاع اتقفل. الفلوس راحت للمتخصصة.'),
  'dispute_release.provider': ('فلوسك', 'النزاع اتقفل والفلوس اتحررت ليكي.'),
  'dispute_split.client': ('تقسيم', 'النزاع اتقفل. جزء هيرجع وجزء للمتخصصة.'),
  'dispute_split.provider': ('تقسيم', 'النزاع اتقفل. جزء من المبلغ اتحرر ليكي.'),
  'refunded.client': ('استرداد', 'المبلغ هيرجع للطريقة اللي دفعتي بيها.'),
  'refunded.provider': ('استرداد', 'الحجز اترجع. مفيش صرف على الزيارة دي.'),
  'released.client': ('اتقفلت', 'الزيارة خلصت. الفلوس راحت للمتخصصة.'),
  'released.provider': ('فلوسك', 'الفلوس اتحررت ليكي.'),
  'rescheduled.client': ('تأجيل', 'ميعاد الزيارة اتغيّر.'),
  'rescheduled.provider': ('تأجيل', 'ميعاد الزيارة اتغيّر. شوفي الجدول.'),
  'payout': ('فلوسك', 'في مبلغ بقى متاح للسحب.'),
  'payout_held': ('إيقاف سحب', 'طلب السحب واقف للمراجعة.'),
  'vetted': ('تمام التوثيق', 'حسابك اتراجع واتفتح للعميلات.'),
  'rejected': ('مراجعة الهوية', 'مقدرتش نوثّق الحساب دلوقتي. هنتواصل لو احتجنا حاجة.'),
};

const _en = <String, (String, String)>{
  'default': ('Oons', "There's an update on a visit."),
  'paid': ('New booking', 'A client paid. Open the visit.'),
  'paid.client': ('Paid', 'Your booking is confirmed.'),
  'paid.provider': ('New booking', 'A client paid. Open the visit.'),
  'pending_payment.client': ('Waiting for payment', 'This booking is still unpaid.'),
  'pending_payment.provider': ('Waiting for payment', 'The client has not paid yet.'),
  'on_the_way': ('On the way', 'Your professional is on the way.'),
  'on_the_way.client': ('On the way', 'Your professional is on the way.'),
  'on_the_way.provider': ('On the way', 'She knows you are on the way.'),
  'at_door': ('At the door', "She has arrived. Confirm if you haven't."),
  'at_door.client': ('At the door', "She has arrived. Confirm if you haven't."),
  'at_door.provider': ('At the door', 'Waiting for her to confirm you arrived.'),
  'in_progress': ('Visit started', 'The visit is running now.'),
  'in_progress.client': ('Visit started', 'The visit is running now.'),
  'in_progress.provider': ('Visit started', 'She confirmed. The visit is running.'),
  'completed': ('Visit ended', 'The visit is closed.'),
  'completed.client': ('Visit ended', 'You can rate her now.'),
  'completed.provider': ('Visit ended', 'The visit is closed. Earnings review after the hold.'),
  'cancelled_provider': ('Cancelled', 'She cancelled. We can find a replacement at the same time.'),
  'cancelled_provider.client': ('Cancelled', 'She cancelled. We can find a replacement at the same time.'),
  'cancelled_provider.provider': ('Cancelled', 'This booking was cancelled on your side.'),
  'cancelled_client': ('Cancelled', 'The client cancelled the visit.'),
  'cancelled_client.client': ('Cancelled', 'Your booking was cancelled.'),
  'cancelled_client.provider': ('Cancelled', 'The client cancelled the visit.'),
  'dispute': ('Dispute', 'A visit is under review. Open the details.'),
  'dispute.client': ('Dispute', 'The money stays held until we review.'),
  'dispute.provider': ('Dispute', 'A visit is under review. Open the details.'),
  'disputed.client': ('Dispute', 'The money stays held until we review.'),
  'disputed.provider': ('Dispute', 'A visit is under review. Open the details.'),
  'dispute_refund.client': ('Refund', 'The dispute is closed. The amount goes back to how you paid.'),
  'dispute_refund.provider': ('Refund', 'The dispute closed with a refund. No payout on this visit.'),
  'dispute_release.client': ('Closed', 'The dispute closed and she was paid.'),
  'dispute_release.provider': ('Your money', 'The dispute closed and the amount was released to you.'),
  'dispute_split.client': ('Split', 'The dispute closed. Part refunded, part paid to her.'),
  'dispute_split.provider': ('Split', 'The dispute closed. Part of the amount was released to you.'),
  'refunded.client': ('Refund', 'The amount goes back to how you paid.'),
  'refunded.provider': ('Refund', 'This booking was refunded. No payout.'),
  'released.client': ('Closed', 'The visit closed and the amount was released.'),
  'released.provider': ('Your money', 'The amount was released to you.'),
  'rescheduled.client': ('Rescheduled', 'The visit time changed.'),
  'rescheduled.provider': ('Rescheduled', 'The visit time changed. Check your list.'),
  'payout': ('Your money', 'An amount is available to withdraw.'),
  'payout_held': ('Payout held', 'This withdrawal is paused for review.'),
  'vetted': ('Verified', 'Your profile is live for clients.'),
  'rejected': ('ID review', 'We could not verify the account yet. We will reach you if we need anything.'),
};
