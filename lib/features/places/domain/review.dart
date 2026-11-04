import 'rating.dart';

enum ReviewVote {
  up('up'),
  down('down');

  const ReviewVote(this.wire);
  final String wire;

  static ReviewVote? fromWire(Object? value) => value == 'up'
      ? ReviewVote.up
      : value == 'down'
      ? ReviewVote.down
      : null;
}

enum ReviewReason {
  spam('spam'),
  offensive('offensive'),
  wrongInfo('wrong_info'),
  other('other');

  const ReviewReason(this.wire);
  final String wire;
}

class ReviewVotes {
  const ReviewVotes({this.up = 0, this.down = 0, this.mine});

  final int up;
  final int down;
  final ReviewVote? mine;

  ReviewVotes copyWith({
    int? up,
    int? down,
    ReviewVote? mine,
    bool clearMine = false,
  }) => ReviewVotes(
    up: up ?? this.up,
    down: down ?? this.down,
    mine: clearMine ? null : mine ?? this.mine,
  );
}

class Review {
  const Review({
    required this.id,
    required this.stars,
    required this.text,
    required this.author,
    required this.mine,
    required this.hidden,
    required this.createdAt,
    required this.updatedAt,
    this.votes = const ReviewVotes(),
    this.reported = false,
  });

  final String id;
  final int stars;
  final String text;
  final String author;
  final bool mine;
  final bool hidden;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ReviewVotes votes;
  final bool reported;

  Review copyWith({ReviewVotes? votes, bool? reported, String? text}) => Review(
    id: id,
    stars: stars,
    text: text ?? this.text,
    author: author,
    mine: mine,
    hidden: hidden,
    createdAt: createdAt,
    updatedAt: updatedAt,
    votes: votes ?? this.votes,
    reported: reported ?? this.reported,
  );
}

/// One page of reviews plus the branch summary the page header needs.
class ReviewPage {
  const ReviewPage({
    required this.branchId,
    required this.branchName,
    this.branchLabel,
    required this.rating,
    required this.reviews,
    this.nextOffset,
  });

  final String branchId;
  final String branchName;
  final String? branchLabel;
  final RatingSummary rating;
  final List<Review> reviews;
  final int? nextOffset;

  ReviewPage copyWith({RatingSummary? rating, List<Review>? reviews}) =>
      ReviewPage(
        branchId: branchId,
        branchName: branchName,
        branchLabel: branchLabel,
        rating: rating ?? this.rating,
        reviews: reviews ?? this.reviews,
        nextOffset: nextOffset,
      );
}
