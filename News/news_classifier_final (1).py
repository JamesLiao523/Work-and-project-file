# ==================================================
# NEWS CLASSIFIER - FINAL VERSION WITH RARE CLASS HANDLING
# ==================================================
# 
# Key Features:
# - TF-IDF + Keyword Boosting + Linear SVC
# - Confidence scoring with threshold filtering
# - KEEPS RARE CLASSES (critical for risk/compliance)
# - Special keyword fallback for rare classes
#
# ==================================================

import re
import pickle
import warnings
from datetime import datetime
from collections import Counter

warnings.filterwarnings('ignore')

import numpy as np
import pandas as pd
from sklearn.feature_extraction.text import TfidfVectorizer, ENGLISH_STOP_WORDS
from sklearn.svm import LinearSVC
from sklearn.calibration import CalibratedClassifierCV
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report, accuracy_score, f1_score

# ==================================================
# CONFIGURATION
# ==================================================

GENERIC_STOP_WORDS = set([
    "bank", "company", "group", "financial", "corporation", "inc", "plc", 
    "limited", "llc", "corp", "holdings", "co", "ltd", "www", "http", "https",
    "com", "org", "uk", "stock", "report", "british", "said", "says", "would",
    "could", "also", "one", "two", "three", "first", "second", "new", "year"
])
CUSTOM_STOP_WORDS = list(ENGLISH_STOP_WORDS.union(GENERIC_STOP_WORDS))

CATEGORIES = {
    "Performance / Earnings / Valuation": [
        "Earnings", "Stock Performance", "Analysis Report", "Rating / Valuation", "Valuation"
    ],
    "Corporate Actions": [
        "M&A Deal / Investment", "Business Plan", "Spin-off / Divestment",
        "Capital Raising", "Product Launch / Branding / Marketing", "Investor Relations / Events"
    ],
    "Regulatory / Legal / Compliance": [
        "Regulatory Action", "Compliance Issue", "Trial / Lawsuit", "Settlement / Penalty"
    ],
    "Organization / Personnel": [
        "Executive Appointment", "Key Personnel Departure", "Retirement", "Board Change"
    ],
    "Econ / Market Impact": [
        "Policy", "Macro Data", "Central Bank", "Geopolitics", "Market Volatility"
    ]
}

SUBCAT_TO_CAT = {}
for cat, subs in CATEGORIES.items():
    for sub in subs:
        SUBCAT_TO_CAT[sub] = cat

# ==================================================
# DOMAIN KEYWORDS (Used for rare class detection)
# ==================================================

CATEGORY_KEYWORDS = {
    "Earnings": [
        "earnings", "revenue", "profit", "income", "ebitda", "eps", "dividend",
        "guidance", "forecast", "outlook", "results", "quarterly", "annual",
        "margin", "profitability", "beat", "miss", "consensus", "estimate"
    ],
    "Stock Performance": [
        "stock", "shares", "price", "trading", "volume", "volatility",
        "rally", "selloff", "rebound", "surge", "drop", "rise", "fall",
        "gain", "lose", "advance", "decline", "high", "low", "close",
        "momentum", "correction", "crash", "spike", "dip", "session"
    ],
    "Analysis Report": [
        "analysis", "report", "research", "note", "compares", "peers", "preview",
        "thesis", "outlook", "perspective", "recommendation", "comparative",
        "upgrade", "downgrade", "coverage", "target", "estimate", "sector"
    ],
    "Rating / Valuation": [
        "valuation", "multiple", "ratio", "discount", "premium", "fair",
        "intrinsic", "dcf", "overvalued", "undervalued", "cheap", "expensive",
        "rating", "upgrade", "downgrade", "target", "overweight", "underweight",
        "buy", "hold", "sell", "neutral", "analyst", "price target", "benzinga"
    ],
    "M&A Deal / Investment": [
        "acquire", "acquisition", "acquired", "merger", "merge", "takeover",
        "stake", "deal", "transaction", "investment", "investor", "bid", "offer",
        "buyout", "divestment", "consortium", "shareholder", "ownership",
        "majority", "minority", "agreement", "tender", "privatization"
    ],
    "Business Plan": [
        "strategy", "plan", "roadmap", "transformation", "expansion",
        "initiative", "restructuring", "reorganization", "optimization",
        "efficiency", "pivot", "turnaround", "vision", "mission"
    ],
    "Spin-off / Divestment": [
        "spinoff", "spin-off", "demerger", "divest", "divestiture",
        "carve-out", "separation", "split", "disposal", "exit", "subsidiary"
    ],
    "Capital Raising": [
        "ipo", "offering", "rights", "bond", "capital raise", "raised",
        "placement", "issuance", "fundraising", "proceeds", "raise",
        "prospectus", "registration", "listing", "debut", "float"
    ],
    "Product Launch / Branding / Marketing": [
        "launch", "launched", "launches", "unveil", "unveiled", "release",
        "branding", "marketing", "campaign", "sponsor", "sponsorship",
        "advertising", "promotion", "rebranding", "logo", "trademark", "patent"
    ],
    "Investor Relations / Events": [
        "conference", "investor day", "analyst day", "roadshow", "webcast",
        "earnings call", "presentation", "meeting", "webinar", "host"
    ],
    # === CRITICAL RARE CLASSES FOR RISK/COMPLIANCE ===
    "Regulatory Action": [
        "regulatory", "regulator", "approval", "investigation", "probe",
        "authority", "compliance", "audit", "inspection", "enforcement",
        "license", "permit", "authorization", "sanction", "warning",
        "fca", "sec", "fda", "ftc", "doj", "antitrust", "subpoena"
    ],
    "Compliance Issue": [
        "compliance", "violation", "breach", "noncompliance",
        "controls", "audit finding", "failure", "misconduct",
        "remediation", "corrective", "whistleblower", "ethics"
    ],
    "Trial / Lawsuit": [
        "lawsuit", "court", "appeal", "litigation", "sues", "sued",
        "bankruptcy", "class action", "plaintiff", "defendant",
        "judgment", "verdict", "ruling", "hearing", "trial", "filed"
    ],
    "Settlement / Penalty": [
        "settlement", "settle", "settled", "fine", "fined", "penalty",
        "sanction", "sanctioned", "agreed to pay", "consent decree",
        "damages", "restitution", "compensation", "forfeit", "disgorgement"
    ],
    "Executive Appointment": [
        "appointed", "named", "hired", "joins", "joining", "hire",
        "recruitment", "ceo", "cfo", "coo", "chairman", "president",
        "director", "leadership", "promotion", "promoted", "succession"
    ],
    "Key Personnel Departure": [
        "resign", "resigns", "resigned", "resignation", "steps down",
        "stepping down", "departure", "departs", "departed", "exits",
        "fired", "dismissed", "terminated", "leaves", "leaving", "layoff"
    ],
    "Retirement": [
        "retire", "retired", "retirement", "retires", "retiring"
    ],
    "Board Change": [
        "board change", "board appointment", "board reshuffle",
        "board member", "board composition", "director appointment"
    ],
    "Policy": [
        "policy", "fiscal", "stimulus", "reform", "government",
        "budget", "deficit", "surplus", "spending", "legislation"
    ],
    "Macro Data": [
        "inflation", "cpi", "gdp", "unemployment", "payrolls", "nonfarm",
        "economic data", "retail sales", "consumer confidence", "pmi"
    ],
    "Central Bank": [
        "central bank", "federal reserve", "fed", "monetary policy",
        "rate hike", "rate cut", "interest rate", "quantitative easing"
    ],
    "Geopolitics": [
        "geopolitical", "conflict", "war", "sanctions", "trade dispute",
        "tariffs", "embargo", "diplomacy", "tension", "political"
    ],
    "Market Volatility": [
        "volatility", "turmoil", "correction", "crash", "rebound",
        "swing", "fluctuation", "uncertainty", "instability", "vix"
    ]
}

# ==================================================
# TOKENIZER
# ==================================================

def simple_stem(word):
    word = word.lower()
    suffixes = ['ization', 'ational', 'iveness', 'fulness', 'ousness', 
                'ation', 'eness', 'ment', 'ness', 'tion', 'sion', 'ance', 'ence',
                'able', 'ible', 'ing', 'ity', 'ive', 'ful', 'ous', 'ess',
                'ed', 'ly', 'er', 'es', 'al', 's']
    for suffix in suffixes:
        if word.endswith(suffix) and len(word) > len(suffix) + 2:
            return word[:-len(suffix)]
    return word

def tokenizer(text):
    tokens = re.findall(r"[a-zA-Z]+", text.lower())
    return [simple_stem(t) for t in tokens if len(t) > 2]

# ==================================================
# KEYWORD SCORER (For rare class detection)
# ==================================================

class KeywordScorer:
    """Score text against keyword patterns for rare/critical classes"""
    
    def __init__(self, keywords_dict, rare_classes):
        self.keywords = keywords_dict
        self.rare_classes = set(rare_classes)
    
    def score_text(self, text, category):
        """Score how well text matches a category's keywords (0-1)"""
        if category not in self.keywords:
            return 0.0
        
        text_lower = text.lower()
        keywords = self.keywords[category]
        
        matches = sum(1 for kw in keywords if kw.lower() in text_lower)
        return min(matches / 5.0, 1.0)  # Normalize: 5+ matches = 1.0
    
    def get_rare_class_scores(self, text):
        """Get keyword scores for all rare classes"""
        scores = {}
        for cls in self.rare_classes:
            scores[cls] = self.score_text(text, cls)
        return scores
    
    def check_rare_class_match(self, text, threshold=0.4):
        """Check if text strongly matches any rare class keywords"""
        scores = self.get_rare_class_scores(text)
        best_class = max(scores, key=scores.get)
        best_score = scores[best_class]
        
        if best_score >= threshold:
            return best_class, best_score
        return None, 0.0


# ==================================================
# MAIN CLASSIFIER CLASS
# ==================================================

class NewsClassifier:
    """
    Production-ready news classifier with:
    - Confidence scoring
    - Threshold filtering
    - Rare class handling (keeps all classes, keyword fallback)
    """
    
    def __init__(self, 
                 keyword_boost=2.0, 
                 min_confidence=0.3, 
                 use_calibration=True,
                 rare_class_threshold=10,
                 keyword_rescue_threshold=0.4):
        """
        Args:
            keyword_boost: Multiplier for keyword term weights
            min_confidence: Minimum probability for confident prediction
            use_calibration: Use probability calibration
            rare_class_threshold: Classes with fewer samples are "rare"
            keyword_rescue_threshold: Min keyword score to override ML for rare class
        """
        self.keyword_boost = keyword_boost
        self.min_confidence = min_confidence
        self.use_calibration = use_calibration
        self.rare_class_threshold = rare_class_threshold
        self.keyword_rescue_threshold = keyword_rescue_threshold
        
        self.vectorizer = TfidfVectorizer(
            tokenizer=tokenizer,
            stop_words=CUSTOM_STOP_WORDS,
            ngram_range=(1, 2),
            max_features=8000,
            min_df=1,  # Keep all terms (important for rare classes)
            max_df=0.9,
            sublinear_tf=True
        )
        
        self.subcat_model = None
        self.cat_model = None
        self.keyword_indices = []
        self.keyword_scorer = None
        self.rare_classes = []
        self.class_counts = {}
        
        self.is_fitted = False
        self.classes_subcat = []
        self.classes_cat = []
        self.training_info = {}
        
    def _get_all_keywords(self):
        all_kw = set()
        for keywords in CATEGORY_KEYWORDS.values():
            for kw in keywords:
                all_kw.add(kw.lower())
                for word in kw.lower().split():
                    all_kw.add(simple_stem(word))
        return all_kw
    
    def _find_keyword_indices(self):
        vocab = self.vectorizer.vocabulary_
        all_keywords = self._get_all_keywords()
        self.keyword_indices = []
        for term, idx in vocab.items():
            term_words = set(term.split())
            stemmed_term_words = {simple_stem(w) for w in term_words}
            if any(kw in term or kw in stemmed_term_words for kw in all_keywords):
                self.keyword_indices.append(idx)
    
    def _apply_keyword_boost(self, X):
        if self.keyword_boost == 1.0 or not self.keyword_indices:
            return X
        X_boosted = X.copy()
        for idx in self.keyword_indices:
            X_boosted[:, idx] *= self.keyword_boost
        return X_boosted
    
    def fit(self, texts, subcategories, categories=None, keep_rare=True):
        """
        Train classifier.
        
        Args:
            texts: Article bodies
            subcategories: Subcategory labels
            categories: Category labels (optional)
            keep_rare: If True, keep ALL classes including rare ones
        """
        if categories is None:
            categories = [SUBCAT_TO_CAT.get(s, "Uncertain") for s in subcategories]
        
        # Analyze class distribution
        self.class_counts = Counter(subcategories)
        self.rare_classes = [c for c, n in self.class_counts.items() 
                           if n < self.rare_class_threshold]
        
        print(f"\n{'='*60}")
        print(f"  TRAINING NEWS CLASSIFIER")
        print(f"{'='*60}")
        print(f"  Total samples: {len(texts)}")
        print(f"  Total subcategories: {len(self.class_counts)}")
        print(f"  Rare classes (<{self.rare_class_threshold} samples): {len(self.rare_classes)}")
        
        if self.rare_classes:
            print(f"\n  RARE CLASSES (will use keyword fallback):")
            for cls in sorted(self.rare_classes):
                print(f"    - {cls}: {self.class_counts[cls]} samples")
        
        # Filter data based on keep_rare setting
        if keep_rare:
            # Keep ALL classes, even with 1 sample
            train_texts = texts
            train_subcats = subcategories
            train_cats = categories
            print(f"\n  ✓ Keeping ALL classes (including rare)")
        else:
            # Filter out classes with < 2 samples (can't train)
            valid_mask = [self.class_counts[s] >= 2 for s in subcategories]
            train_texts = [t for t, m in zip(texts, valid_mask) if m]
            train_subcats = [s for s, m in zip(subcategories, valid_mask) if m]
            train_cats = [c for c, m in zip(categories, valid_mask) if m]
            print(f"\n  Filtered to {len(train_texts)} samples (dropped classes with <2 samples)")
        
        # Fit vectorizer
        X = self.vectorizer.fit_transform(train_texts)
        print(f"  Vocabulary size: {len(self.vectorizer.vocabulary_)}")
        
        # Keyword boosting
        self._find_keyword_indices()
        print(f"  Keyword terms boosted: {len(self.keyword_indices)}")
        
        X_boosted = self._apply_keyword_boost(X)
        
        # Train models
        # Filter very rare classes for calibration (need at least 2 samples per class)
        train_class_counts = Counter(train_subcats)
        calibration_mask = [train_class_counts[s] >= 2 for s in train_subcats]
        
        if self.use_calibration and sum(calibration_mask) > 0:
            # Train calibrated model on classes with enough samples
            cal_texts = [t for t, m in zip(train_texts, calibration_mask) if m]
            cal_subcats = [s for s, m in zip(train_subcats, calibration_mask) if m]
            cal_cats = [c for c, m in zip(train_cats, calibration_mask) if m]
            
            cal_X = self.vectorizer.transform(cal_texts)
            cal_X_boosted = self._apply_keyword_boost(cal_X)
            
            min_class_size = min(Counter(cal_subcats).values())
            cv_folds = min(3, min_class_size)
            
            if cv_folds >= 2:
                base_model = LinearSVC(class_weight='balanced', max_iter=10000, C=2.0)
                self.subcat_model = CalibratedClassifierCV(base_model, cv=cv_folds)
                self.subcat_model.fit(cal_X_boosted, cal_subcats)
                
                base_model = LinearSVC(class_weight='balanced', max_iter=10000, C=2.0)
                self.cat_model = CalibratedClassifierCV(base_model, cv=cv_folds)
                self.cat_model.fit(cal_X_boosted, cal_cats)
                
                self.classes_subcat = list(self.subcat_model.classes_)
                self.classes_cat = list(self.cat_model.classes_)
                
                print(f"  ✓ Calibrated on {len(cal_texts)} samples ({len(set(cal_subcats))} classes)")
            else:
                self.use_calibration = False
        else:
            self.use_calibration = False
        
        if not self.use_calibration:
            # Fallback: train uncalibrated on all data
            self.subcat_model = LinearSVC(class_weight='balanced', max_iter=10000, C=2.0)
            self.subcat_model.fit(X_boosted, train_subcats)
            self.classes_subcat = list(set(train_subcats))
            
            self.cat_model = LinearSVC(class_weight='balanced', max_iter=10000, C=2.0)
            self.cat_model.fit(X_boosted, train_cats)
            self.classes_cat = list(set(train_cats))
            print(f"  ⚠ Calibration disabled, using uncalibrated model")
        
        # Setup keyword scorer for rare classes
        self.keyword_scorer = KeywordScorer(CATEGORY_KEYWORDS, self.rare_classes)
        
        self.training_info = {
            'n_samples': len(train_texts),
            'n_subcategories': len(self.classes_subcat),
            'n_categories': len(self.classes_cat),
            'n_rare_classes': len(self.rare_classes),
            'rare_classes': self.rare_classes,
            'class_counts': dict(self.class_counts),
            'trained_at': datetime.now().isoformat()
        }
        
        self.is_fitted = True
        print(f"\n  ✓ Training complete!")
        return self
    
    def predict(self, texts, use_keyword_rescue=True):
        """
        Predict with optional keyword rescue for rare classes.
        
        Args:
            texts: Article text(s)
            use_keyword_rescue: If True, check keywords for rare classes when ML is uncertain
            
        Returns:
            List of (category, subcategory, confidence, source) tuples
            source = 'ml' or 'keyword_rescue'
        """
        if not self.is_fitted:
            raise ValueError("Classifier not fitted.")
        
        if isinstance(texts, str):
            texts = [texts]
            single_input = True
        else:
            single_input = False
        
        X = self.vectorizer.transform(texts)
        X_boosted = self._apply_keyword_boost(X)
        
        ml_subcat_preds = self.subcat_model.predict(X_boosted)
        ml_cat_preds = self.cat_model.predict(X_boosted)
        
        results = []
        
        # Get probabilities if available
        if self.use_calibration and hasattr(self.subcat_model, 'predict_proba'):
            ml_probs = self.subcat_model.predict_proba(X_boosted)
        else:
            ml_probs = None
        
        for i, text in enumerate(texts):
            ml_subcat = ml_subcat_preds[i]
            ml_cat = ml_cat_preds[i]
            ml_conf = float(np.max(ml_probs[i])) if ml_probs is not None else 0.5
            
            # Check if we should rescue with keywords
            source = 'ml'
            final_subcat = ml_subcat
            final_cat = ml_cat
            final_conf = ml_conf
            
            if use_keyword_rescue and self.keyword_scorer:
                # If ML confidence is low OR ML predicted a common class,
                # check if keywords suggest a rare class
                if ml_conf < 0.5 or ml_subcat not in self.rare_classes:
                    kw_class, kw_score = self.keyword_scorer.check_rare_class_match(
                        text, threshold=self.keyword_rescue_threshold
                    )
                    
                    if kw_class is not None:
                        # Strong keyword match for rare class
                        # Only override if keyword score > ML confidence for that class
                        if kw_score > ml_conf * 0.8:  # Give ML some benefit of doubt
                            final_subcat = kw_class
                            final_cat = SUBCAT_TO_CAT.get(kw_class, "Uncertain")
                            final_conf = kw_score
                            source = 'keyword_rescue'
            
            results.append((final_cat, final_subcat, round(final_conf, 3), source))
        
        return results[0] if single_input else results
    
    def predict_simple(self, texts):
        """Simple predict returning (category, subcategory, confidence)"""
        results = self.predict(texts)
        if isinstance(results, tuple):
            return (results[0], results[1], results[2])
        return [(r[0], r[1], r[2]) for r in results]
    
    def predict_with_threshold(self, texts, confidence_threshold=0.5):
        """Predict with threshold - low confidence → Manual Review"""
        predictions = self.predict(texts)
        if isinstance(predictions, tuple):
            predictions = [predictions]
        
        results = []
        for cat, subcat, conf, source in predictions:
            is_confident = conf >= confidence_threshold
            if is_confident:
                results.append((cat, subcat, conf, source, True))
            else:
                results.append(("Uncertain", "Manual Review", conf, source, False))
        return results
    
    def analyze_confidence_thresholds(self, texts, true_subcategories, true_categories=None):
        """Analyze accuracy vs coverage at different thresholds"""
        if true_categories is None:
            true_categories = [SUBCAT_TO_CAT.get(s, "Uncertain") for s in true_subcategories]
        
        predictions = self.predict(texts)
        pred_cats = [p[0] for p in predictions]
        pred_subs = [p[1] for p in predictions]
        confidences = [p[2] for p in predictions]
        sources = [p[3] for p in predictions]
        
        thresholds = [0.0, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8]
        results = []
        
        for thresh in thresholds:
            mask = [c >= thresh for c in confidences]
            n_kept = sum(mask)
            
            if n_kept == 0:
                results.append({
                    'threshold': thresh, 'coverage': 0, 'n_kept': 0,
                    'n_filtered': len(texts), 'n_keyword_rescue': 0,
                    'subcat_accuracy': 0, 'cat_accuracy': 0
                })
                continue
            
            filtered_true_sub = [s for s, m in zip(true_subcategories, mask) if m]
            filtered_pred_sub = [s for s, m in zip(pred_subs, mask) if m]
            filtered_true_cat = [c for c, m in zip(true_categories, mask) if m]
            filtered_pred_cat = [c for c, m in zip(pred_cats, mask) if m]
            filtered_sources = [s for s, m in zip(sources, mask) if m]
            
            results.append({
                'threshold': thresh,
                'coverage': n_kept / len(texts),
                'n_kept': n_kept,
                'n_filtered': len(texts) - n_kept,
                'n_keyword_rescue': sum(1 for s in filtered_sources if s == 'keyword_rescue'),
                'subcat_accuracy': accuracy_score(filtered_true_sub, filtered_pred_sub),
                'cat_accuracy': accuracy_score(filtered_true_cat, filtered_pred_cat)
            })
        
        return pd.DataFrame(results)
    
    def print_confidence_analysis(self, texts, true_subcategories, true_categories=None):
        """Print confidence analysis table"""
        df = self.analyze_confidence_thresholds(texts, true_subcategories, true_categories)
        
        print(f"\n{'='*100}")
        print(f"  CONFIDENCE THRESHOLD ANALYSIS")
        print(f"{'='*100}")
        print(f"  Total: {len(texts)} | Rare classes: {len(self.rare_classes)}")
        print(f"\n  {'Thresh':<8} {'Coverage':<10} {'Kept':<8} {'Review':<8} {'KW Rescue':<12} {'SubCat Acc':<12} {'Cat Acc':<12}")
        print("-" * 100)
        
        for _, row in df.iterrows():
            print(f"  {row['threshold']:<8.1f} {row['coverage']:<10.1%} {int(row['n_kept']):<8} {int(row['n_filtered']):<8} {int(row['n_keyword_rescue']):<12} {row['subcat_accuracy']:<12.1%} {row['cat_accuracy']:<12.1%}")
        
        return df
    
    def evaluate_rare_classes(self, texts, true_subcategories):
        """Evaluate performance specifically on rare classes"""
        predictions = self.predict(texts)
        pred_subs = [p[1] for p in predictions]
        sources = [p[3] for p in predictions]
        
        print(f"\n{'='*80}")
        print(f"  RARE CLASS PERFORMANCE")
        print(f"{'='*80}")
        
        for cls in self.rare_classes:
            # Find samples of this class
            indices = [i for i, s in enumerate(true_subcategories) if s == cls]
            
            if not indices:
                continue
            
            correct = sum(1 for i in indices if pred_subs[i] == cls)
            kw_rescued = sum(1 for i in indices if sources[i] == 'keyword_rescue')
            
            accuracy = correct / len(indices) if indices else 0
            
            print(f"  {cls}:")
            print(f"    Samples: {len(indices)} | Correct: {correct} | Accuracy: {accuracy:.1%}")
            print(f"    Keyword rescued: {kw_rescued}")
    
    def save(self, filepath):
        if not self.is_fitted:
            raise ValueError("Classifier not fitted.")
        
        model_data = {
            'vectorizer': self.vectorizer,
            'subcat_model': self.subcat_model,
            'cat_model': self.cat_model,
            'keyword_indices': self.keyword_indices,
            'keyword_boost': self.keyword_boost,
            'min_confidence': self.min_confidence,
            'use_calibration': self.use_calibration,
            'rare_class_threshold': self.rare_class_threshold,
            'keyword_rescue_threshold': self.keyword_rescue_threshold,
            'classes_subcat': self.classes_subcat,
            'classes_cat': self.classes_cat,
            'rare_classes': self.rare_classes,
            'class_counts': self.class_counts,
            'training_info': self.training_info
        }
        
        with open(filepath, 'wb') as f:
            pickle.dump(model_data, f)
        print(f"✓ Model saved to {filepath}")
    
    @classmethod
    def load(cls, filepath):
        with open(filepath, 'rb') as f:
            data = pickle.load(f)
        
        classifier = cls(
            keyword_boost=data['keyword_boost'],
            min_confidence=data['min_confidence'],
            use_calibration=data['use_calibration'],
            rare_class_threshold=data.get('rare_class_threshold', 10),
            keyword_rescue_threshold=data.get('keyword_rescue_threshold', 0.4)
        )
        
        classifier.vectorizer = data['vectorizer']
        classifier.subcat_model = data['subcat_model']
        classifier.cat_model = data['cat_model']
        classifier.keyword_indices = data['keyword_indices']
        classifier.classes_subcat = data['classes_subcat']
        classifier.classes_cat = data['classes_cat']
        classifier.rare_classes = data.get('rare_classes', [])
        classifier.class_counts = data.get('class_counts', {})
        classifier.training_info = data['training_info']
        classifier.keyword_scorer = KeywordScorer(CATEGORY_KEYWORDS, classifier.rare_classes)
        classifier.is_fitted = True
        
        print(f"✓ Model loaded | Rare classes: {len(classifier.rare_classes)}")
        return classifier


# ==================================================
# BATCH CLASSIFICATION
# ==================================================

def classify_news_file(input_file, output_file, model_path=None, classifier=None, confidence_threshold=None):
    """Classify news from Excel with confidence filtering"""
    if classifier is None:
        classifier = NewsClassifier.load(model_path)
    
    df = pd.read_excel(input_file)
    texts = df['Body'].fillna('').tolist()
    
    predictions = classifier.predict(texts)
    
    df['Predicted_Category'] = [p[0] for p in predictions]
    df['Predicted_Subcategory'] = [p[1] for p in predictions]
    df['Confidence'] = [p[2] for p in predictions]
    df['Prediction_Source'] = [p[3] for p in predictions]  # 'ml' or 'keyword_rescue'
    
    if confidence_threshold:
        df['Is_Confident'] = df['Confidence'] >= confidence_threshold
        df['Needs_Review'] = ~df['Is_Confident']
        df.loc[~df['Is_Confident'], 'Predicted_Category'] = 'Uncertain'
        df.loc[~df['Is_Confident'], 'Predicted_Subcategory'] = 'Manual Review'
    
    df.to_excel(output_file, index=False)
    
    # Summary
    n_kw = sum(1 for p in predictions if p[3] == 'keyword_rescue')
    print(f"✓ Classified {len(df)} articles | {n_kw} keyword-rescued")
    return df


# ==================================================
# MAIN
# ==================================================

if __name__ == "__main__":
    
    # Load ALL data (including rare classes)
    print("\n" + "="*60)
    print("  LOADING DATA (KEEPING RARE CLASSES)")
    print("="*60)
    
    df = pd.read_excel("/mnt/user-data/uploads/News_Data_train.xlsx")
    
    # Only drop "Uncertain" label, keep everything else
    df = df[df['Subcategory'] != 'Uncertain'].copy()
    
    texts = df['Body'].fillna('').tolist()
    subcategories = df['Subcategory'].tolist()
    categories = df['Category'].tolist()
    
    print(f"  Total samples: {len(texts)}")
    print(f"  Subcategories: {len(set(subcategories))}")
    
    # Show class distribution
    print(f"\n  CLASS DISTRIBUTION:")
    for cls, count in sorted(Counter(subcategories).items(), key=lambda x: x[1], reverse=True):
        marker = "⚠ RARE" if count < 10 else ""
        print(f"    {cls}: {count} {marker}")
    
    # Train/test split - handle very rare classes
    # Classes with only 1 sample can't be stratified, so we filter them for split
    # but keep them in final training
    class_counts = Counter(subcategories)
    valid_for_split = [c >= 2 for c in [class_counts[s] for s in subcategories]]
    
    texts_splittable = [t for t, v in zip(texts, valid_for_split) if v]
    subcats_splittable = [s for s, v in zip(subcategories, valid_for_split) if v]
    cats_splittable = [c for c, v in zip(categories, valid_for_split) if v]
    
    X_train, X_test, y_sub_train, y_sub_test, y_cat_train, y_cat_test = train_test_split(
        texts_splittable, subcats_splittable, cats_splittable, 
        test_size=0.25, random_state=42, stratify=subcats_splittable
    )
    
    # Add very rare samples (1-sample classes) to training only
    very_rare = [(t, s, c) for t, s, c, v in zip(texts, subcategories, categories, valid_for_split) if not v]
    if very_rare:
        print(f"\n  Adding {len(very_rare)} very rare samples to training only")
        for t, s, c in very_rare:
            X_train.append(t)
            y_sub_train.append(s)
            y_cat_train.append(c)
    
    # Train classifier (keeping rare classes)
    clf = NewsClassifier(
        keyword_boost=2.0,
        min_confidence=0.3,
        use_calibration=True,
        rare_class_threshold=15,  # Classes with <15 samples are "rare"
        keyword_rescue_threshold=0.4  # Keyword score needed to rescue
    )
    clf.fit(X_train, y_sub_train, y_cat_train, keep_rare=True)
    
    # Confidence analysis
    clf.print_confidence_analysis(X_test, y_sub_test, y_cat_test)
    
    # Rare class evaluation
    clf.evaluate_rare_classes(X_test, y_sub_test)
    
    # Train final model on all data
    print(f"\n{'='*60}")
    print("  TRAINING FINAL MODEL ON ALL DATA")
    print("="*60)
    
    final_clf = NewsClassifier(
        keyword_boost=2.0,
        rare_class_threshold=15,
        keyword_rescue_threshold=0.4
    )
    final_clf.fit(texts, subcategories, categories, keep_rare=True)
    final_clf.save("/home/claude/news_classifier_final.pkl")
    
    # Summary
    print(f"\n{'='*80}")
    print("  SUMMARY: RARE CLASS HANDLING")
    print("="*80)
    print(f"""
  FLOW:
  
  1. TEXT INPUT
       ↓
  2. TF-IDF + KEYWORD BOOST (2x for domain terms)
       ↓
  3. ML PREDICTION (Linear SVC with balanced class weights)
       ↓
  4. CONFIDENCE SCORE (Calibrated probability)
       ↓
  5. KEYWORD RESCUE CHECK (For rare classes)
       │
       ├─ If ML confidence < 0.5 AND keywords match rare class → Use keyword prediction
       │
       └─ Otherwise → Use ML prediction
       ↓
  6. THRESHOLD FILTER
       │
       ├─ Confidence >= threshold → Accept
       │
       └─ Confidence < threshold → Manual Review
       ↓
  OUTPUT: (Category, Subcategory, Confidence, Source)
  
  
  WHY KEEP RARE CLASSES?
  
  - In risk/compliance, rare events are CRITICAL
  - "Settlement / Penalty" with 3 samples might be the most important
  - Keyword fallback catches what ML can't learn from few samples
  
  
  USAGE:
  
    clf = NewsClassifier.load("news_classifier_final.pkl")
    
    # Predict with keyword rescue for rare classes
    results = clf.predict(texts, use_keyword_rescue=True)
    
    for cat, subcat, conf, source in results:
        if source == 'keyword_rescue':
            print(f"RARE CLASS DETECTED: {{subcat}} (keywords)")
        else:
            print(f"{{subcat}} (ML, {{conf:.0%}} confidence)")
    """)
