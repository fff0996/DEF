"""RDKit descriptor 기반 AutoGluon 학습 인터페이스.

Dataset -> AutoGluonTrainer.train -> do_train/predict API를 제공하며,
CPU 환경에서 사용자 RT 모델을 학습하고 예측합니다.
"""
from autogluon.tabular import TabularPredictor


class Dataset:
    def __init__(self, training, validation, target_column="rt"):
        self.target_column = target_column
        self.datasets = {"training": training, "validation": validation}

    def get_training_data(self):
        return self.datasets["training"]

    def get_validation_data(self):
        return self.datasets["validation"]


class Trainer:
    def __init__(self, dataset):
        self.dataset = dataset
        self.predictor = None
        self.model_columns = None

    def train(self):
        for name, df in self.dataset.datasets.items():
            if self.dataset.target_column not in df.columns:
                raise ValueError(f"Missing target in {name}")
        self.do_train()
        return self

    def predict(self, data):
        return self.predictor.predict(data[self.model_columns])


class AutoGluonTrainer(Trainer):
    def __init__(self, dataset, path, time_limit=1200, cpus=2, algorithms=None, seed=42):
        super().__init__(dataset)
        self.path = str(path)
        self.time_limit = time_limit
        self.cpus = cpus
        self.algorithms = algorithms or ["GBM", "CAT", "RF", "XT", "KNN"]
        self.seed = seed

    def do_train(self):
        training_data = self.dataset.get_training_data()
        self.model_columns = [c for c in training_data if c != self.dataset.target_column]
        hyperparameters = {}
        for family in self.algorithms:
            settings = {}
            if family in ("RF", "XT"):
                settings.update(n_estimators=200, random_state=self.seed)
            elif family == "GBM":
                settings["seed"] = self.seed
            elif family == "CAT":
                settings["random_seed"] = self.seed
            hyperparameters[family] = settings
        self.predictor = TabularPredictor(label=self.dataset.target_column, problem_type="regression",
                                         eval_metric="root_mean_squared_error", path=self.path, verbosity=1)
        self.predictor.fit(train_data=training_data, tuning_data=self.dataset.get_validation_data(),
                           time_limit=self.time_limit, presets="medium_quality", hyperparameters=hyperparameters,
                           num_gpus=0, num_cpus=self.cpus, num_bag_folds=0, num_stack_levels=0,
                           dynamic_stacking=False, refit_full=False, set_best_to_refit_full=False)
