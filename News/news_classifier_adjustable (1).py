# ==================================================
# NEWS CLASSIFIER WITH ADJUSTABLE HEADLINE/BODY WEIGHTS
# ==================================================
#
# Allows you to experiment with different weights:
# - headline_weight: How much to weight headline (0.0 - 10.0)
# - body_weight: How much to weight body (0.0 - 10.0)
#
# Examples:
#   headline_weight=1, body_weight=1  → Equal weight
#   headline_weight=3, body_weight=1  → Headline 3x more important
#   headline_weight=0, body_weight=1  → Body only
#   headline_weight=1, body_weight=0  → Headline only
#
# ==================================================

import pandas as pd
import numpy as np
import re
import pickle
from collections import Counter
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.svm import LinearSVC
from sklearn.calibration import CalibratedClassifierCV
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, f1_score
import warnings
warnings.filterwarnings('ignore')

# ==================================================
# CONFIGURATION
# ==================================================

SUBCAT_TO_CAT = {
    "M&A Deal / Investment": "Corporate Actions",
    "Capital Raising": "Corporate Actions",
    "Business Plan": "Corporate Actions",
    "Product Launch / Branding / Marketing": "Corporate Actions",
    "Spin-off / Divestment": "Corporate Actions",
    "Investor Relations / Events": "Corporate Actions",
    "Earnings": "Performance / Earnings / Valuation",
    "Stock Performance": "Performance / Earnings / Valuation",
    "Rating / Valuation": "Performance / Earnings / Valuation",
    "Analysis Report": "Performance / Earnings / Valuation",
    "Valuation": "Performance / Earnings / Valuation",
    "Executive Appointment": "Organization / Personnel",
    "Key Personnel Departure": "Organization / Personnel",
    "Retirement": "Organization / Personnel",
    "Board Change": "Organization / Personnel",
    "Settlement / Penalty": "Regulatory / Legal / Compliance",
    "Regulatory Action": "Regulatory / Legal / Compliance",
    "Trial / Lawsuit": "Regulatory / Legal / Compliance",
    "Compliance Issue": "Regulatory / Legal / Compliance",
    "Macro Data": "Econ / Market Impact",
    "Central Bank": "Econ / Market Impact",
    "Policy": "Econ / Market Impact",
}

CATEGORY_KEYWORDS = {
    "Settlement / Penalty": ["settlement", "fine", "fined", "penalty", "sanction", "agreed to pay"],
    "Regulatory Action": ["regulatory", "investigation", "probe", "sec", "fca", "enforcement"],
    "Trial / Lawsuit": ["lawsuit", "court", "litigation", "sued", "trial", "verdict"],
    "Key Personnel Departure": ["resign", "resigned", "departure", "steps down", "fired", "leaves"],
    "Executive Appointment": ["appointed", "named", "hired", "joins", "ceo", "cfo", "promoted"],
    "Capital Raising": ["ipo", "offering", "bond", "fundraising", "raise", "listing"],
    "Macro Data": ["inflation", "gdp", "unemployment", "economic data", "pmi"],
    "Central Bank": ["fed", "federal reserve", "rate hike", "rate cut", "interest rate"],
}

def tokenizer(text):
    tokens = re.findall(r"[a-zA-Z]+", text.lower())
    return [t for t in tokens if len(t) > 2]


# ==================================================
# MAIN CLASSIFIER
# ==================================================

class NewsClassifierAdjustable:
    """
    News classifier with adjustable headline/body weights.
    
    Experiment with different weight combinations to find optimal settings.
    """
    
    def __init__(self, 
                 headline_weight=1.0,
                 body_weight=1.0,
                 keyword_boost=2.0,
                 rare_class_threshold=15,
                 keyword_rescue_threshold=0.4):
        """
        Args:
            headline_weight: Weight for headline text (0.0 - 10.0)
            body_weight: Weight for body text (0.0 - 10.0)
            keyword_boost: Boost for domain keywords
            rare_class_threshold: Classes with fewer samples are "rare"
            keyword_rescue_threshold: Min score for keyword rescue
        """
        self.headline_weight = headline_weight
        self.body_weight = body_weight
        self.keyword_boost = keyword_boost
        self.rare_class_threshold = rare_class_threshold
        self.keyword_rescue_threshold = keyword_rescue_threshold
        
        self.vectorizer = None
        self.model = None
        self.classes_ = []
        self.rare_classes = []
        self.is_fitted = False
    
    def _combine_text(self, headline, body):
        """
        Combine headline and body with weights.
        
        Weight is applied by repeating text proportionally.
        E.g., headline_weight=2, body_weight=1 means headline appears 2x.
        """
        headline = str(headline) if pd.notna(headline) and headline else ""
        body = str(body) if pd.notna(body) and body else ""
        
        parts = []
        
        # Add headline based on weight
        if self.headline_weight > 0 and headline.strip():
            repeat = max(1, int(self.headline_weight))
            for _ in range(repeat):
                parts.append(headline)
        
        # Add body based on weight
        if self.body_weight > 0 and body.strip():
            repeat = max(1, int(self.body_weight))
            for _ in range(repeat):
                parts.append(body)
        
        return ' '.join(parts) if parts else ""
    
    def _get_keyword_indices(self, vocab):
        """Find indices of keyword terms in vocabulary"""
        all_kw = set()
        for keywords in CATEGORY_KEYWORDS.values():
            for kw in keywords:
                all_kw.add(kw.lower())
        
        indices = []
        for term, idx in vocab.items():
            if any(kw in term for kw in all_kw):
                indices.append(idx)
        return indices
    
    def _apply_keyword_boost(self, X, indices):
        """Apply boost to keyword terms"""
        if self.keyword_boost == 1.0 or not indices:
            return X
        X_boosted = X.copy()
        for idx in indices:
            X_boosted[:, idx] *= self.keyword_boost
        return X_boosted
    
    def _keyword_rescue(self, text, ml_confidence):
        """Check if keywords suggest a rare class"""
        text_lower = text.lower()
        
        best_class = None
        best_score = 0
        
        for cls in self.rare_classes:
            if cls not in CATEGORY_KEYWORDS:
                continue
            keywords = CATEGORY_KEYWORDS[cls]
            matches = sum(1 for kw in keywords if kw in text_lower)
            score = min(matches / 3.0, 1.0)
            
            if score > best_score:
                best_score = score
                best_class = cls
        
        if best_score >= self.keyword_rescue_threshold and best_score > ml_confidence * 0.8:
            return best_class, best_score
        return None, 0
    
    def fit(self, headlines, bodies, subcategories, categories=None):
        """Train the classifier"""
        if categories is None:
            categories = [SUBCAT_TO_CAT.get(s, "Uncertain") for s in subcategories]
        
        # Analyze classes
        class_counts = Counter(subcategories)
        self.rare_classes = [c for c, n in class_counts.items() 
                           if n < self.rare_class_threshold]
        
        print(f"\n{'='*60}")
        print(f"  TRAINING CLASSIFIER")
        print(f"{'='*60}")
        print(f"  Headline weight: {self.headline_weight}")
        print(f"  Body weight: {self.body_weight}")
        print(f"  Samples: {len(bodies)}")
        
        # Combine texts
        combined = [self._combine_text(h, b) for h, b in zip(headlines, bodies)]
        
        # Vectorize
        self.vectorizer = TfidfVectorizer(
            tokenizer=tokenizer,
            ngram_range=(1, 2),
            max_features=5000,
            min_df=2,
            max_df=0.9,
            sublinear_tf=True
        )
        
        X = self.vectorizer.fit_transform(combined)
        
        # Keyword boost
        kw_indices = self._get_keyword_indices(self.vectorizer.vocabulary_)
        X_boosted = self._apply_keyword_boost(X, kw_indices)
        
        # Train
        self.model = LinearSVC(class_weight='balanced', max_iter=10000, C=2.0)
        self.model.fit(X_boosted, subcategories)
        self.classes_ = list(set(subcategories))
        
        self.kw_indices = kw_indices
        self.is_fitted = True
        print(f"  ✓ Training complete!")
        
        return self
    
    def predict(self, headlines, bodies, confidence_threshold=None):
        """Predict categories"""
        single = isinstance(headlines, str)
        if single:
            headlines = [headlines]
            bodies = [bodies]
        
        combined = [self._combine_text(h, b) for h, b in zip(headlines, bodies)]
        
        X = self.vectorizer.transform(combined)
        X_boosted = self._apply_keyword_boost(X, self.kw_indices)
        
        preds = self.model.predict(X_boosted)
        
        # Get confidence from decision function
        decision = self.model.decision_function(X_boosted)
        if len(decision.shape) == 1:
            confidences = 1 / (1 + np.exp(-np.abs(decision)))
        else:
            confidences = 1 / (1 + np.exp(-np.max(decision, axis=1)))
        
        results = []
        for i in range(len(combined)):
            subcat = preds[i]
            conf = float(confidences[i])
            source = 'ml'
            
            # Keyword rescue
            kw_class, kw_score = self._keyword_rescue(combined[i], conf)
            if kw_class:
                subcat = kw_class
                conf = kw_score
                source = 'keyword_rescue'
            
            cat = SUBCAT_TO_CAT.get(subcat, "Uncertain")
            
            if confidence_threshold and conf < confidence_threshold:
                results.append({
                    'category': 'Uncertain',
                    'subcategory': 'Manual Review',
                    'confidence': round(conf, 3),
                    'is_confident': False,
                    'source': source
                })
            else:
                results.append({
                    'category': cat,
                    'subcategory': subcat,
                    'confidence': round(conf, 3),
                    'is_confident': True,
                    'source': source
                })
        
        return results[0] if single else results
    
    def evaluate(self, headlines, bodies, true_subcats):
        """Evaluate and return metrics"""
        results = self.predict(headlines, bodies)
        pred_subcats = [r['subcategory'] for r in results]
        
        acc = accuracy_score(true_subcats, pred_subcats)
        f1 = f1_score(true_subcats, pred_subcats, average='weighted', zero_division=0)
        
        return {'accuracy': acc, 'f1': f1}
    
    def save(self, filepath):
        """Save model"""
        with open(filepath, 'wb') as f:
            pickle.dump({
                'headline_weight': self.headline_weight,
                'body_weight': self.body_weight,
                'keyword_boost': self.keyword_boost,
                'vectorizer': self.vectorizer,
                'model': self.model,
                'kw_indices': self.kw_indices,
                'classes_': self.classes_,
                'rare_classes': self.rare_classes
            }, f)
        print(f"✓ Saved to {filepath}")
    
    @classmethod
    def load(cls, filepath):
        """Load model"""
        with open(filepath, 'rb') as f:
            data = pickle.load(f)
        
        clf = cls(
            headline_weight=data['headline_weight'],
            body_weight=data['body_weight'],
            keyword_boost=data['keyword_boost']
        )
        clf.vectorizer = data['vectorizer']
        clf.model = data['model']
        clf.kw_indices = data['kw_indices']
        clf.classes_ = data['classes_']
        clf.rare_classes = data['rare_classes']
        clf.is_fitted = True
        return clf


# ==================================================
# EXPERIMENT FUNCTION
# ==================================================

def experiment_weights(train_file, test_ratio=0.25):
    """
    Experiment with different headline/body weight combinations.
    
    Args:
        train_file: Path to training Excel file
        test_ratio: Ratio for test split
    """
    # Load data
    print("Loading data...")
    df = pd.read_excel(train_file)
    df = df[df['Subcategory'] != 'Uncertain'].copy()
    
    # Filter classes
    class_counts = Counter(df['Subcategory'])
    valid_mask = [class_counts[s] >= 2 for s in df['Subcategory']]
    df = df[valid_mask].copy()
    
    # Split
    train_df, test_df = train_test_split(
        df, test_size=test_ratio, random_state=42, stratify=df['Subcategory']
    )
    
    print(f"Train: {len(train_df)} | Test: {len(test_df)}")
    
    # Weight combinations to test
    weight_combinations = [
        # (headline_weight, body_weight, description)
        (0, 1, "Body Only"),
        (1, 0, "Headline Only"),
        (1, 1, "Equal (1:1)"),
        (2, 1, "Headline 2x"),
        (3, 1, "Headline 3x"),
        (5, 1, "Headline 5x"),
        (1, 2, "Body 2x"),
        (1, 3, "Body 3x"),
        (0.5, 1, "Headline 0.5x"),
        (1.5, 1, "Headline 1.5x"),
        (2, 2, "Both 2x"),
        (3, 2, "Headline 3x, Body 2x"),
    ]
    
    results = []
    
    print("\n" + "="*70)
    print("  EXPERIMENTING WITH DIFFERENT WEIGHTS")
    print("="*70)
    print(f"\n  {'Description':<25} {'H:B Ratio':<15} {'Accuracy':<12} {'F1 Score':<12}")
    print("-"*70)
    
    for h_weight, b_weight, desc in weight_combinations:
        clf = NewsClassifierAdjustable(
            headline_weight=h_weight,
            body_weight=b_weight,
            keyword_boost=2.0
        )
        
        clf.fit(
            train_df['Headline'].fillna('').tolist(),
            train_df['Body'].fillna('').tolist(),
            train_df['Subcategory'].tolist()
        )
        
        metrics = clf.evaluate(
            test_df['Headline'].fillna('').tolist(),
            test_df['Body'].fillna('').tolist(),
            test_df['Subcategory'].tolist()
        )
        
        ratio = f"{h_weight}:{b_weight}"
        results.append((desc, h_weight, b_weight, metrics['accuracy'], metrics['f1']))
        
        print(f"  {desc:<25} {ratio:<15} {metrics['accuracy']:<12.1%} {metrics['f1']:<12.1%}")
    
    # Sort by F1 score
    results.sort(key=lambda x: x[4], reverse=True)
    
    print("\n" + "="*70)
    print("  RANKING (by F1 Score)")
    print("="*70)
    print(f"\n  {'Rank':<6} {'Description':<25} {'H:B':<10} {'Accuracy':<12} {'F1 Score':<12}")
    print("-"*70)
    
    for i, (desc, h, b, acc, f1) in enumerate(results, 1):
        marker = "← BEST" if i == 1 else ""
        print(f"  {i:<6} {desc:<25} {h}:{b:<7} {acc:<12.1%} {f1:<12.1%} {marker}")
    
    # Best settings
    best = results[0]
    print(f"\n" + "="*70)
    print(f"  BEST SETTINGS")
    print(f"="*70)
    print(f"""
  Headline Weight: {best[1]}
  Body Weight:     {best[2]}
  F1 Score:        {best[4]:.1%}
  Accuracy:        {best[3]:.1%}
    """)
    
    return results


def quick_test(headline_weight, body_weight, train_file):
    """
    Quick test with specific weights.
    
    Usage:
        quick_test(2, 1, "News_Data_train.xlsx")
    """
    df = pd.read_excel(train_file)
    df = df[df['Subcategory'] != 'Uncertain'].copy()
    
    class_counts = Counter(df['Subcategory'])
    valid_mask = [class_counts[s] >= 2 for s in df['Subcategory']]
    df = df[valid_mask].copy()
    
    train_df, test_df = train_test_split(
        df, test_size=0.25, random_state=42, stratify=df['Subcategory']
    )
    
    clf = NewsClassifierAdjustable(
        headline_weight=headline_weight,
        body_weight=body_weight
    )
    
    clf.fit(
        train_df['Headline'].fillna('').tolist(),
        train_df['Body'].fillna('').tolist(),
        train_df['Subcategory'].tolist()
    )
    
    metrics = clf.evaluate(
        test_df['Headline'].fillna('').tolist(),
        test_df['Body'].fillna('').tolist(),
        test_df['Subcategory'].tolist()
    )
    
    print(f"\n  Headline Weight: {headline_weight}")
    print(f"  Body Weight: {body_weight}")
    print(f"  Accuracy: {metrics['accuracy']:.1%}")
    print(f"  F1 Score: {metrics['f1']:.1%}")
    
    return clf, metrics


# ==================================================
# MAIN
# ==================================================

if __name__ == "__main__":
    
    # Run experiment
    results = experiment_weights("/mnt/user-data/uploads/News_Data_train.xlsx")
    
    # Train final model with best settings
    best = results[0]
    print(f"\n" + "="*70)
    print(f"  TRAINING FINAL MODEL WITH BEST WEIGHTS")
    print(f"="*70)
    
    df = pd.read_excel("/mnt/user-data/uploads/News_Data_train.xlsx")
    df = df[df['Subcategory'] != 'Uncertain'].copy()
    
    final_clf = NewsClassifierAdjustable(
        headline_weight=best[1],
        body_weight=best[2],
        keyword_boost=2.0
    )
    
    final_clf.fit(
        df['Headline'].fillna('').tolist(),
        df['Body'].fillna('').tolist(),
        df['Subcategory'].tolist()
    )
    
    final_clf.save("/mnt/user-data/outputs/news_classifier_best_weights.pkl")
    
    print(f"""
    
  USAGE:
  ══════════════════════════════════════════════════════════════════
  
  # Experiment with different weights
  from news_classifier_adjustable import experiment_weights, quick_test
  
  # Run full experiment
  results = experiment_weights("News_Data_train.xlsx")
  
  # Quick test specific weights
  clf, metrics = quick_test(
      headline_weight=2,
      body_weight=1,
      train_file="News_Data_train.xlsx"
  )
  
  # Use trained classifier
  from news_classifier_adjustable import NewsClassifierAdjustable
  
  clf = NewsClassifierAdjustable(headline_weight=2, body_weight=1)
  clf.fit(headlines, bodies, subcategories)
  
  result = clf.predict("Apple acquires startup", "Apple Inc today announced...")
  print(result)
  
  # Load saved model
  clf = NewsClassifierAdjustable.load("news_classifier_best_weights.pkl")
    """)
