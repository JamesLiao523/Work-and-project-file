# ==================================================
# HEADLINE CLASSIFIER V5 - OPTIMIZED FOR HEADLINE-ONLY DATA
# ==================================================
#
# Trained on: 838 headlines, 21 subcategories
# Best settings: LinearSVC C=10, ngram=(1,2), max_features=8000
#
# Results:
#   Subcategory Accuracy: 70.1%
#   Subcategory F1:       69.1%
#   Category Accuracy:    82.0%
#
# ==================================================

import pandas as pd
import numpy as np
import re
import pickle
from collections import Counter
from datetime import datetime
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.svm import LinearSVC
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, f1_score, classification_report
import warnings
warnings.filterwarnings('ignore')

# ==================================================
# CONFIGURATION
# ==================================================

SUBCAT_TO_CAT = {
    # Corporate Actions
    "M&A Deal / Investment": "Corporate Actions",
    "Capital Raising": "Corporate Actions",
    "Business Plan": "Corporate Actions",
    "Product Launch / Branding / Marketing": "Corporate Actions",
    "Spin-off / Divestment": "Corporate Actions",
    "Investor Relations / Events": "Corporate Actions",
    "Partnership / Alliance": "Corporate Actions",
    
    # Performance / Earnings / Valuation
    "Earnings": "Performance / Earnings / Valuation",
    "Stock Performance": "Performance / Earnings / Valuation",
    "Rating / Valuation": "Performance / Earnings / Valuation",
    "Analysis Report": "Performance / Earnings / Valuation",
    "Valuation": "Performance / Earnings / Valuation",
    
    # Organization / Personnel
    "Executive Appointment": "Organization / Personnel",
    "Key Personnel Departure": "Organization / Personnel",
    "Board Change": "Organization / Personnel",
    
    # Regulatory / Legal / Compliance
    "Settlement / Penalty": "Regulatory / Legal / Compliance",
    "Regulatory Action": "Regulatory / Legal / Compliance",
    "Trial / Lawsuit": "Regulatory / Legal / Compliance",
    "Compliance Issue": "Regulatory / Legal / Compliance",
    
    # Econ / Market Impact
    "Macro Data": "Econ / Market Impact",
    "Central Bank": "Econ / Market Impact",
    "Policy": "Econ / Market Impact",
}

# Keywords for rare classes (< 15 samples)
SUBCATEGORY_KEYWORDS = {
    "Settlement / Penalty": ["settlement", "settle", "settled", "fine", "fined", "penalty", "agreed to pay", "consent decree"],
    "Regulatory Action": ["regulatory", "investigation", "probe", "sec ", "fca ", "fda", "antitrust", "approval", "cleared"],
    "Trial / Lawsuit": ["lawsuit", "court", "litigation", "sues", "sued", "class action", "verdict", "trial", "plaintiff"],
    "Compliance Issue": ["compliance", "violation", "breach", "misconduct", "whistleblower", "fraud", "irregularities"],
    "Key Personnel Departure": ["resign", "resigns", "resigned", "steps down", "departure", "leaves", "fired", "ousted", "exit", "quits"],
    "Board Change": ["board of directors", "board member", "board seat", "director appointed", "joins board"],
    "Investor Relations / Events": ["investor day", "investor conference", "analyst day", "shareholder meeting", "earnings call", "capital markets day"],
    "Partnership / Alliance": ["partnership", "partner", "partners", "alliance", "collaborate", "joint venture", "team up", "strategic agreement"],
    "Spin-off / Divestment": ["spin-off", "spinoff", "divest", "divestment", "sells unit", "sells division", "carve-out"],
    "Macro Data": ["inflation", "cpi", "gdp", "unemployment", "payrolls", "economic data", "retail sales", "pmi"],
    "Policy": ["government policy", "legislation", "tax reform", "tariff", "sanctions", "regulation change"],
    "Valuation": ["valuation", "valued at", "market cap", "enterprise value", "fair value", "worth billion"],
}

def tokenizer(text):
    """Simple tokenizer"""
    tokens = re.findall(r"[a-zA-Z]+", text.lower())
    return [t for t in tokens if len(t) > 2]


class HeadlineClassifierV5:
    """
    Optimized classifier for headline-only data.
    
    Uses hybrid approach:
    - ML (TF-IDF + SVM) for classes with >= 15 samples
    - Keyword rescue for rare classes when ML confidence is low
    """
    
    def __init__(self,
                 C=10.0,
                 max_features=8000,
                 min_samples_for_ml=15,
                 confidence_threshold=0.4):
        self.C = C
        self.max_features = max_features
        self.min_samples_for_ml = min_samples_for_ml
        self.confidence_threshold = confidence_threshold
        
        self.vectorizer = None
        self.model = None
        self.ml_classes = []
        self.keyword_classes = []
        self.class_counts = {}
        self.is_fitted = False
    
    def _keyword_predict(self, headline):
        """Predict using keywords for rare classes"""
        text_lower = headline.lower()
        best_class, best_score = None, 0
        
        for subcat, keywords in SUBCATEGORY_KEYWORDS.items():
            if subcat not in self.keyword_classes:
                continue
            matches = sum(1 for kw in keywords if kw in text_lower)
            if matches > best_score:
                best_score = matches
                best_class = subcat
        
        return best_class, best_score
    
    def fit(self, headlines, subcategories):
        """Train the classifier"""
        self.class_counts = Counter(subcategories)
        
        # Split classes by sample count
        self.ml_classes = [c for c, n in self.class_counts.items() 
                         if n >= self.min_samples_for_ml and c != 'Uncertain']
        self.keyword_classes = [c for c, n in self.class_counts.items() 
                               if n < self.min_samples_for_ml and c != 'Uncertain']
        
        print(f"\n{'='*60}")
        print(f"  TRAINING HEADLINE CLASSIFIER V5")
        print(f"{'='*60}")
        print(f"  Samples: {len(headlines)}")
        print(f"  Subcategories: {len(self.class_counts)}")
        print(f"  ML classes (>={self.min_samples_for_ml}): {len(self.ml_classes)}")
        print(f"  Keyword classes (<{self.min_samples_for_ml}): {len(self.keyword_classes)}")
        
        # Vectorize
        self.vectorizer = TfidfVectorizer(
            tokenizer=tokenizer,
            ngram_range=(1, 2),
            max_features=self.max_features,
            min_df=1,
            max_df=0.9,
            sublinear_tf=True
        )
        
        X = self.vectorizer.fit_transform(headlines)
        print(f"  Vocabulary: {len(self.vectorizer.vocabulary_)} terms")
        
        # Train SVM
        self.model = LinearSVC(
            class_weight='balanced',
            max_iter=10000,
            C=self.C
        )
        self.model.fit(X, subcategories)
        
        self.is_fitted = True
        print(f"  ✓ Training complete!")
        return self
    
    def predict(self, headlines):
        """Predict subcategories"""
        if not self.is_fitted:
            raise ValueError("Classifier not fitted")
        
        single = isinstance(headlines, str)
        if single:
            headlines = [headlines]
        
        # ML predictions
        X = self.vectorizer.transform(headlines)
        ml_preds = self.model.predict(X)
        ml_decisions = self.model.decision_function(X)
        ml_conf = 1 / (1 + np.exp(-np.max(np.abs(ml_decisions), axis=1)))
        
        # Hybrid: ML + keyword rescue
        results = []
        for i, headline in enumerate(headlines):
            ml_pred = ml_preds[i]
            conf = float(ml_conf[i])
            method = 'ml'
            
            # Keyword rescue for rare classes
            kw_pred, kw_score = self._keyword_predict(headline)
            if kw_pred and kw_score >= 1 and conf < 0.7:
                ml_pred = kw_pred
                conf = min(kw_score / 2, 1.0)
                method = 'keyword_rescue'
            
            cat = SUBCAT_TO_CAT.get(ml_pred, 'Uncertain')
            is_confident = conf >= self.confidence_threshold
            
            results.append({
                'category': cat if is_confident else 'Uncertain',
                'subcategory': ml_pred if is_confident else 'Uncertain',
                'confidence': round(conf, 3),
                'is_confident': is_confident,
                'method': method
            })
        
        return results[0] if single else results
    
    def predict_dataframe(self, df, headline_col='Headline'):
        """Predict from DataFrame"""
        headlines = df[headline_col].fillna('').tolist()
        results = self.predict(headlines)
        
        df_out = df.copy()
        df_out['Predicted_Category'] = [r['category'] for r in results]
        df_out['Predicted_Subcategory'] = [r['subcategory'] for r in results]
        df_out['Confidence'] = [r['confidence'] for r in results]
        df_out['Is_Confident'] = [r['is_confident'] for r in results]
        df_out['Method'] = [r['method'] for r in results]
        
        return df_out
    
    def evaluate(self, headlines, true_subcats, verbose=True):
        """Evaluate classifier"""
        results = self.predict(headlines)
        pred_subcats = [r['subcategory'] for r in results]
        
        true_cats = [SUBCAT_TO_CAT.get(s, 'Uncertain') for s in true_subcats]
        pred_cats = [SUBCAT_TO_CAT.get(s, 'Uncertain') for s in pred_subcats]
        
        metrics = {
            'subcategory_accuracy': accuracy_score(true_subcats, pred_subcats),
            'subcategory_f1': f1_score(true_subcats, pred_subcats, average='weighted', zero_division=0),
            'category_accuracy': accuracy_score(true_cats, pred_cats),
        }
        
        if verbose:
            print(f"\n{'='*60}")
            print(f"  EVALUATION RESULTS")
            print(f"{'='*60}")
            print(f"  Subcategory Accuracy: {metrics['subcategory_accuracy']:.1%}")
            print(f"  Subcategory F1:       {metrics['subcategory_f1']:.1%}")
            print(f"  Category Accuracy:    {metrics['category_accuracy']:.1%}")
        
        return metrics
    
    def save(self, filepath):
        """Save model"""
        with open(filepath, 'wb') as f:
            pickle.dump({
                'vectorizer': self.vectorizer,
                'model': self.model,
                'ml_classes': self.ml_classes,
                'keyword_classes': self.keyword_classes,
                'class_counts': dict(self.class_counts),
                'C': self.C,
                'max_features': self.max_features,
                'min_samples_for_ml': self.min_samples_for_ml,
                'confidence_threshold': self.confidence_threshold,
            }, f)
        print(f"✓ Model saved to {filepath}")
    
    @classmethod
    def load(cls, filepath):
        """Load model"""
        with open(filepath, 'rb') as f:
            data = pickle.load(f)
        
        clf = cls(
            C=data['C'],
            max_features=data['max_features'],
            min_samples_for_ml=data['min_samples_for_ml'],
            confidence_threshold=data['confidence_threshold'],
        )
        clf.vectorizer = data['vectorizer']
        clf.model = data['model']
        clf.ml_classes = data['ml_classes']
        clf.keyword_classes = data['keyword_classes']
        clf.class_counts = data['class_counts']
        clf.is_fitted = True
        
        print(f"✓ Model loaded")
        return clf


# ==================================================
# MAIN
# ==================================================

if __name__ == "__main__":
    # Load data
    df = pd.read_excel("/mnt/user-data/uploads/Trained_Headline.xlsx")
    df = df[df['Subcategory'] != 'Uncertain'].copy()
    
    # Split
    class_counts = Counter(df['Subcategory'])
    df_multi = df[[class_counts[s] >= 2 for s in df['Subcategory']]].copy()
    df_single = df[[class_counts[s] == 1 for s in df['Subcategory']]].copy()
    
    train_df, test_df = train_test_split(
        df_multi, test_size=0.2, random_state=42, stratify=df_multi['Subcategory']
    )
    train_df = pd.concat([train_df, df_single], ignore_index=True)
    
    print(f"Train: {len(train_df)} | Test: {len(test_df)}")
    
    # Train
    clf = HeadlineClassifierV5(C=10.0, max_features=8000, confidence_threshold=0.4)
    clf.fit(
        train_df['Headline'].fillna('').tolist(),
        train_df['Subcategory'].tolist()
    )
    
    # Evaluate
    clf.evaluate(
        test_df['Headline'].fillna('').tolist(),
        test_df['Subcategory'].tolist()
    )
    
    # Train on ALL data
    print("\n\nTraining final model on ALL data...")
    final_clf = HeadlineClassifierV5(C=10.0, max_features=8000, confidence_threshold=0.4)
    final_clf.fit(
        df['Headline'].fillna('').tolist(),
        df['Subcategory'].tolist()
    )
    final_clf.save("/mnt/user-data/outputs/headline_classifier_v5.pkl")
    
    # Test examples
    print("\n\nTEST EXAMPLES:")
    print("="*60)
    
    test_headlines = [
        "Apple acquires AI startup for $1 billion",
        "CEO resigns amid scandal",
        "SEC launches investigation into accounting practices",
        "Company announces Q3 earnings beat",
        "Stock surges 10% on positive news",
        "Analyst upgrades rating to Buy",
    ]
    
    for headline in test_headlines:
        result = final_clf.predict(headline)
        print(f"\n  \"{headline}\"")
        print(f"  → {result['subcategory']} ({result['confidence']:.0%}) [{result['method']}]")
